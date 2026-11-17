package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/cenkalti/backoff/v4"
	vault "github.com/hashicorp/vault/api"
	awsauth "github.com/hashicorp/vault/api/auth/aws"
)

// Config holds configuration parameters for the Vault client and authentication.
type Config struct {
	VaultAddr     string
	VaultCACert   string
	RoleName      string
	AuthMountPath string
	STSRegion     string
	KVMountPath   string
	KVSecretPath  string
	CheckInterval time.Duration
}

// loadConfig loads configuration from environment variables with sensible defaults.
func loadConfig() *Config {
	cfg := &Config{
		VaultAddr:     os.Getenv("VAULT_ADDR"),
		VaultCACert:   os.Getenv("VAULT_CACERT"),
		RoleName:      os.Getenv("VAULT_ROLE"),
		AuthMountPath: os.Getenv("VAULT_AUTH_MOUNT_PATH"),
		STSRegion:     os.Getenv("VAULT_STS_REGION"),
		KVMountPath:   os.Getenv("KV_MOUNT_PATH"),
		KVSecretPath:  os.Getenv("KV_SECRET_PATH"),
		CheckInterval: 30 * time.Second,
	}

	if cfg.AuthMountPath == "" {
		cfg.AuthMountPath = "aws"
	}

	if cfg.KVMountPath == "" {
		cfg.KVMountPath = "secret"
	}

	if cfg.KVSecretPath == "" {
		cfg.KVSecretPath = "sample"
	}

	// If VAULT_ROLE is not explicitly provided, attempt to derive it from AWS_ROLE_ARN
	// In IRSA setup, AWS_ROLE_ARN is injected automatically (e.g., arn:aws:iam::123456789012:role/consume-pod-role-xxxx)
	if cfg.RoleName == "" {
		if roleArn := os.Getenv("AWS_ROLE_ARN"); roleArn != "" {
			parts := strings.Split(roleArn, "/")
			cfg.RoleName = parts[len(parts)-1]
		}
	}

	return cfg
}

func main() {
	log.Println("================================================================")
	log.Println(" HashiCorp Vault Go SDK Client - IRSA AWS Auth & Auto-Relogin")
	log.Println("================================================================")

	cfg := loadConfig()

	log.Printf("[Config] VAULT_ADDR:             %s", cfg.VaultAddr)
	log.Printf("[Config] VAULT_CACERT:           %s", cfg.VaultCACert)
	log.Printf("[Config] AWS Role Name:          %s", cfg.RoleName)
	log.Printf("[Config] Auth Mount Path:        %s", cfg.AuthMountPath)
	if cfg.STSRegion != "" {
		log.Printf("[Config] STS Signing Region:     %s", cfg.STSRegion)
	} else {
		log.Println("[Config] STS Signing Region:     us-east-1 (global sts.amazonaws.com)")
	}
	log.Printf("[Config] KV Mount Path:          %s", cfg.KVMountPath)
	log.Printf("[Config] KV Secret Path:         %s", cfg.KVSecretPath)
	if webIdentity := os.Getenv("AWS_WEB_IDENTITY_TOKEN_FILE"); webIdentity != "" {
		log.Printf("[Config] AWS Web Identity Token: %s", webIdentity)
	}

	// 1. Initialize Vault Client
	vaultConfig := vault.DefaultConfig()
	if cfg.VaultAddr != "" {
		vaultConfig.Address = cfg.VaultAddr
	}

	// Read standard environment variables (VAULT_ADDR, VAULT_CACERT, VAULT_SKIP_VERIFY, etc.)
	if err := vaultConfig.ReadEnvironment(); err != nil {
		log.Fatalf("[Error] Failed to read Vault environment settings: %v", err)
	}

	client, err := vault.NewClient(vaultConfig)
	if err != nil {
		log.Fatalf("[Error] Failed to initialize Vault client: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Channel to signal that initial authentication succeeded
	initialAuthCh := make(chan struct{}, 1)
	var wg sync.WaitGroup

	// 2. Start Background Auth Manager with Auto-Relogin Loop
	// Handles initial login, LifetimeWatcher renewals, and automatic re-authentication
	// when the token reaches its maximum TTL (max_ttl) or is revoked.
	wg.Add(1)
	go func() {
		defer wg.Done()
		runAuthManager(ctx, client, cfg, initialAuthCh)
	}()

	// Wait for initial login before proceeding to read secrets
	select {
	case <-initialAuthCh:
		log.Println("\n[App] Initial authentication confirmed. Starting application workload...")
	case <-ctx.Done():
		log.Println("[App] Context cancelled before initial login completed.")
		return
	}

	// 3. Initial secret read after login
	log.Println("\n[KV Secret] Fetching initial KV secret...")
	fetchKVSecret(ctx, client, cfg.KVMountPath, cfg.KVSecretPath)

	// 4. Start periodic workload loop (re-reads secret, verifying authenticated connection)
	log.Println("\n[Running] Entering monitoring loop (Press Ctrl+C to terminate)...")
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(cfg.CheckInterval)
	defer ticker.Stop()

	for {
		select {
		case <-sigChan:
			log.Println("\n[Shutdown] Received termination signal. Cancelling context and exiting...")
			cancel()
			wg.Wait()
			log.Println("[Shutdown] All background routines stopped. Goodbye!")
			return
		case <-ticker.C:
			log.Println("[Periodic Check] Verifying Vault connection and reading secret...")
			fetchKVSecret(ctx, client, cfg.KVMountPath, cfg.KVSecretPath)
		}
	}
}

// runAuthManager manages the complete authentication lifecycle:
// It logs in using exponential backoff (cenkalti/backoff), starts the LifetimeWatcher,
// and when the token reaches max TTL or expires, it automatically re-authenticates.
func runAuthManager(ctx context.Context, client *vault.Client, cfg *Config, initialAuthCh chan struct{}) {
	var once sync.Once

	for {
		if ctx.Err() != nil {
			return
		}

		var authSecret *vault.Secret

		// Configure exponential backoff for login attempts
		expBackoff := backoff.NewExponentialBackOff()
		expBackoff.InitialInterval = 1 * time.Second
		expBackoff.MaxInterval = 30 * time.Second
		expBackoff.MaxElapsedTime = 0 // Retry indefinitely until context cancelled

		loginOp := func() error {
			if ctx.Err() != nil {
				return backoff.Permanent(ctx.Err())
			}

			log.Println("\n[AuthManager] Initiating AWS IAM login with IRSA credentials...")
			secret, err := loginAWS(ctx, client, cfg)
			if err != nil {
				return err
			}
			authSecret = secret
			return nil
		}

		notifyOp := func(err error, d time.Duration) {
			log.Printf("[AuthManager] Login failed: %v. Retrying in %v...", err, d.Round(time.Millisecond))
		}

		if err := backoff.RetryNotify(loginOp, backoff.WithContext(expBackoff, ctx), notifyOp); err != nil {
			if ctx.Err() != nil {
				return
			}
			log.Printf("[AuthManager] Login retry aborted: %v", err)
			return
		}

		clientToken := authSecret.Auth.ClientToken
		client.SetToken(clientToken)

		log.Println("[AuthManager] Login successful!")
		log.Printf("  ├── Client Token:    %s... (truncated)", maskToken(clientToken))
		log.Printf("  ├── Policies:        %v", authSecret.Auth.Policies)
		log.Printf("  ├── Lease Duration:  %d seconds", authSecret.Auth.LeaseDuration)
		log.Printf("  ├── Renewable:       %v", authSecret.Auth.Renewable)
		log.Printf("  └── Metadata:        %v", authSecret.Auth.Metadata)

		// Signal initial auth completion
		once.Do(func() {
			close(initialAuthCh)
		})

		// If token is renewable, watch and renew it until max_ttl or expiration
		if authSecret.Auth.Renewable {
			log.Println("[AuthManager] Initializing LifetimeWatcher for token renewal...")
			watcher, err := client.NewLifetimeWatcher(&vault.LifetimeWatcherInput{
				Secret: authSecret,
			})
			if err != nil {
				log.Printf("[AuthManager] Failed to create LifetimeWatcher: %v. Will re-login...", err)
				continue
			}

			go watcher.Start()

			// Block until token renewal finishes (max TTL, revocation, or context cancel)
			watchErr := watchTokenLifecycle(ctx, watcher)
			watcher.Stop()

			if ctx.Err() != nil {
				return
			}

			if watchErr != nil {
				log.Printf("[AuthManager] Token watcher ended with error: %v. Initiating re-login...", watchErr)
			} else {
				log.Println("[AuthManager] Token reached maximum TTL or renewal ended. Initiating re-login for a fresh token...")
			}
		} else {
			// Non-renewable token: sleep until lease expires then re-login
			sleepDuration := time.Duration(authSecret.Auth.LeaseDuration) * time.Second
			if sleepDuration <= 0 {
				sleepDuration = 5 * time.Minute
			}
			log.Printf("[AuthManager] Token is not renewable. Will re-login after lease duration (%v)...", sleepDuration)

			select {
			case <-ctx.Done():
				return
			case <-time.After(sleepDuration):
				log.Println("[AuthManager] Non-renewable token lease ended. Re-authenticating...")
			}
		}
	}
}

// loginAWS prepares the AWS IAM auth method and performs the login request against Vault.
func loginAWS(ctx context.Context, client *vault.Client, cfg *Config) (*vault.Secret, error) {
	var loginOpts []awsauth.LoginOption
	loginOpts = append(loginOpts, awsauth.WithIAMAuth())

	if cfg.RoleName != "" {
		loginOpts = append(loginOpts, awsauth.WithRole(cfg.RoleName))
	}

	if cfg.AuthMountPath != "" && cfg.AuthMountPath != "aws" {
		loginOpts = append(loginOpts, awsauth.WithMountPath(cfg.AuthMountPath))
	}

	if cfg.STSRegion != "" {
		loginOpts = append(loginOpts, awsauth.WithRegion(cfg.STSRegion))
	}

	awsAuthMethod, err := awsauth.NewAWSAuth(loginOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS auth method: %w", err)
	}

	authSecret, err := client.Auth().Login(ctx, awsAuthMethod)
	if err != nil {
		return nil, fmt.Errorf("vault login request failed: %w", err)
	}

	if authSecret == nil || authSecret.Auth == nil {
		return nil, fmt.Errorf("vault login returned empty auth metadata")
	}

	return authSecret, nil
}

// watchTokenLifecycle monitors the LifetimeWatcher channels and logs renewals until completion.
func watchTokenLifecycle(ctx context.Context, watcher *vault.LifetimeWatcher) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case err, ok := <-watcher.DoneCh():
			if !ok {
				return nil
			}
			return err
		case renewal, ok := <-watcher.RenewCh():
			if !ok {
				return nil
			}
			if renewal != nil && renewal.Secret != nil && renewal.Secret.Auth != nil {
				log.Printf("[TokenWatcher] Token renewed successfully! Remaining Lease Duration: %ds (Renewable: %v)",
					renewal.Secret.Auth.LeaseDuration, renewal.Secret.Auth.Renewable)
			} else {
				log.Println("[TokenWatcher] Token renewed successfully.")
			}
		}
	}
}

// fetchKVSecret attempts to read a secret from Vault KV v2 (with fallback to KV v1 / Logical Read).
func fetchKVSecret(ctx context.Context, client *vault.Client, mountPath, secretPath string) {
	log.Printf("[KV Secret] Querying path '%s/data/%s' (KV v2)...", mountPath, secretPath)

	// Attempt KV v2 read
	secret, err := client.KVv2(mountPath).Get(ctx, secretPath)
	if err == nil && secret != nil && secret.Data != nil {
		log.Println("[KV Secret] Successfully retrieved KV v2 secret:")
		for k, v := range secret.Data {
			log.Printf("  ├── %s: %v", k, v)
		}
		if secret.VersionMetadata != nil {
			log.Printf("  └── Version: %d (Created: %s)", secret.VersionMetadata.Version, secret.VersionMetadata.CreatedTime.Format(time.RFC3339))
		}
		return
	}

	// If KV v2 didn't find data or errored, try direct Logical Read
	logicalPath := fmt.Sprintf("%s/%s", mountPath, secretPath)
	log.Printf("[KV Secret] KV v2 read returned (%v). Trying logical read on '%s'...", err, logicalPath)

	logicalSecret, logicalErr := client.Logical().ReadWithContext(ctx, logicalPath)
	if logicalErr == nil && logicalSecret != nil && logicalSecret.Data != nil {
		log.Printf("[KV Secret] Successfully retrieved secret via logical read on '%s':", logicalPath)
		for k, v := range logicalSecret.Data {
			log.Printf("  ├── %s: %v", k, v)
		}
		return
	}

	log.Printf("[KV Secret] Note: Could not fetch secret from '%s/%s'.", mountPath, secretPath)
	log.Printf("  Reason: %v (Logical: %v)", err, logicalErr)
	log.Println("  Tip: Ensure the KV secrets engine is enabled at the mount path and the role's policy grants 'read' permission on this path.")
}

// maskToken masks most characters of a token string for safe logging.
func maskToken(token string) string {
	if len(token) <= 8 {
		return "********"
	}
	return token[:6] + "..." + token[len(token)-4:]
}
