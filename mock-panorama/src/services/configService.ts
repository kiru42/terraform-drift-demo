import fs from 'fs/promises';
import path from 'path';
import { FirewallConfig, PolicyRule, DriftEvent } from '../types/config';
import logger from '../utils/logger';

const DATA_DIR = path.join(__dirname, '../../data');
const CONFIG_FILE = path.join(DATA_DIR, 'config.json');

/**
 * Service handling firewall configuration management
 */
class ConfigService {
  private config: FirewallConfig;

  constructor() {
    this.config = this.getDefaultConfig();
  }

  /**
   * Get default baseline configuration
   */
  private getDefaultConfig(): FirewallConfig {
    return {
      version: '1.0.0',
      device: {
        hostname: 'panorama-mock',
        model: 'PA-5220'
      },
      policies: {
        security: [
          {
            name: 'allow_internal_web',
            source: ['10.0.0.0/8'],
            destination: ['any'],
            service: ['http', 'https'],
            action: 'allow',
            enabled: true,
            description: 'Allow internal networks to access web'
          },
          {
            name: 'block_external_ssh',
            source: ['any'],
            destination: ['10.0.0.0/8'],
            service: ['ssh'],
            action: 'drop',
            enabled: true,
            description: 'Block external SSH to internal networks'
          }
        ]
      },
      metadata: {
        lastModified: new Date().toISOString(),
        modifiedBy: 'terraform'
      }
    };
  }

  /**
   * Initialize service (load from file if exists)
   */
  async init(): Promise<void> {
    try {
      await fs.mkdir(DATA_DIR, { recursive: true });
      
      try {
        const data = await fs.readFile(CONFIG_FILE, 'utf-8');
        this.config = JSON.parse(data);
        logger.info('Loaded configuration from file');
      } catch (error) {
        // File doesn't exist, use default
        await this.saveConfig();
        logger.info('Initialized with default configuration');
      }
    } catch (error) {
      logger.error('Failed to initialize config service', { error });
      throw error;
    }
  }

  /**
   * Get current configuration
   */
  getConfig(): FirewallConfig {
    return JSON.parse(JSON.stringify(this.config)); // Deep clone
  }

  /**
   * Update entire configuration
   */
  async updateConfig(newConfig: FirewallConfig): Promise<void> {
    logger.info('Updating configuration', { 
      oldVersion: this.config.version,
      newVersion: newConfig.version
    });

    this.config = {
      ...newConfig,
      metadata: {
        lastModified: new Date().toISOString(),
        modifiedBy: 'terraform'
      }
    };

    await this.saveConfig();
    logger.info('Configuration updated successfully');
  }

  /**
   * Inject drift (simulate manual firewall change)
   */
  async injectDrift(driftEvent: DriftEvent): Promise<void> {
    logger.warn('Drift injection requested', { driftEvent });

    if (driftEvent.rule) {
      // Add new rule to simulate manual change
      this.config.policies.security.push({
        ...driftEvent.rule,
        enabled: true
      });

      this.config.metadata = {
        lastModified: new Date().toISOString(),
        modifiedBy: 'manual-admin'
      };

      await this.saveConfig();
      logger.warn('Drift injected: new rule added', { rule: driftEvent.rule.name });
    } else if (driftEvent.action === 'modify_first') {
      // Modify first rule
      if (this.config.policies.security.length > 0) {
        this.config.policies.security[0].action = 'deny';
        this.config.metadata = {
          lastModified: new Date().toISOString(),
          modifiedBy: 'manual-admin'
        };
        await this.saveConfig();
        logger.warn('Drift injected: first rule modified');
      }
    } else if (driftEvent.action === 'delete_last') {
      // Delete last rule
      if (this.config.policies.security.length > 0) {
        const deleted = this.config.policies.security.pop();
        this.config.metadata = {
          lastModified: new Date().toISOString(),
          modifiedBy: 'manual-admin'
        };
        await this.saveConfig();
        logger.warn('Drift injected: rule deleted', { rule: deleted?.name });
      }
    }
  }

  /**
   * Reset to default configuration
   */
  async reset(): Promise<void> {
    logger.info('Resetting to default configuration');
    this.config = this.getDefaultConfig();
    await this.saveConfig();
    logger.info('Configuration reset complete');
  }

  /**
   * Save configuration to file
   */
  private async saveConfig(): Promise<void> {
    try {
      await fs.writeFile(
        CONFIG_FILE,
        JSON.stringify(this.config, null, 2),
        'utf-8'
      );
      logger.debug('Configuration saved to file');
    } catch (error) {
      logger.error('Failed to save configuration', { error });
      throw error;
    }
  }

  /**
   * Get configuration hash for drift detection
   */
  getConfigHash(): string {
    const configStr = JSON.stringify(this.config.policies);
    return Buffer.from(configStr).toString('base64').substring(0, 16);
  }
}

export default new ConfigService();
