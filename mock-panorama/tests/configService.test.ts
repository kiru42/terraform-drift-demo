import configService from '../src/services/configService';
import { FirewallConfig } from '../src/types/config';

describe('ConfigService', () => {
  beforeEach(async () => {
    await configService.reset();
  });

  describe('getConfig', () => {
    it('should return default configuration', () => {
      const config = configService.getConfig();
      
      expect(config).toBeDefined();
      expect(config.version).toBe('1.0.0');
      expect(config.device.hostname).toBe('panorama-mock');
      expect(config.policies.security).toHaveLength(2);
    });

    it('should return a deep clone', () => {
      const config1 = configService.getConfig();
      const config2 = configService.getConfig();
      
      expect(config1).not.toBe(config2);
      expect(config1).toEqual(config2);
    });
  });

  describe('updateConfig', () => {
    it('should update configuration successfully', async () => {
      const newConfig: FirewallConfig = {
        version: '2.0.0',
        device: {
          hostname: 'panorama-updated',
          model: 'PA-7080'
        },
        policies: {
          security: [
            {
              name: 'new_rule',
              source: ['192.168.1.0/24'],
              destination: ['any'],
              service: ['https'],
              action: 'allow',
              enabled: true
            }
          ]
        },
        metadata: {
          lastModified: new Date().toISOString(),
          modifiedBy: 'test'
        }
      };

      await configService.updateConfig(newConfig);
      const config = configService.getConfig();

      expect(config.version).toBe('2.0.0');
      expect(config.device.hostname).toBe('panorama-updated');
      expect(config.policies.security).toHaveLength(1);
      expect(config.metadata.modifiedBy).toBe('terraform');
    });
  });

  describe('injectDrift', () => {
    it('should inject drift by adding a new rule', async () => {
      const originalConfig = configService.getConfig();
      const originalLength = originalConfig.policies.security.length;

      await configService.injectDrift({
        rule: {
          name: 'rogue_rule',
          source: ['any'],
          destination: ['any'],
          service: ['any'],
          action: 'allow',
          enabled: true,
          description: 'Unauthorized rule'
        }
      });

      const config = configService.getConfig();
      expect(config.policies.security).toHaveLength(originalLength + 1);
      expect(config.policies.security[originalLength].name).toBe('rogue_rule');
      expect(config.metadata.modifiedBy).toBe('manual-admin');
    });

    it('should inject drift by modifying first rule', async () => {
      await configService.injectDrift({ action: 'modify_first' });

      const config = configService.getConfig();
      expect(config.policies.security[0].action).toBe('deny');
      expect(config.metadata.modifiedBy).toBe('manual-admin');
    });

    it('should inject drift by deleting last rule', async () => {
      const originalConfig = configService.getConfig();
      const originalLength = originalConfig.policies.security.length;

      await configService.injectDrift({ action: 'delete_last' });

      const config = configService.getConfig();
      expect(config.policies.security).toHaveLength(originalLength - 1);
    });
  });

  describe('reset', () => {
    it('should reset to default configuration', async () => {
      // Modify config
      await configService.injectDrift({
        rule: {
          name: 'temp_rule',
          source: ['any'],
          destination: ['any'],
          service: ['any'],
          action: 'allow',
          enabled: true
        }
      });

      // Reset
      await configService.reset();

      const config = configService.getConfig();
      expect(config.policies.security).toHaveLength(2);
      expect(config.policies.security.find(r => r.name === 'temp_rule')).toBeUndefined();
    });
  });

  describe('getConfigHash', () => {
    it('should return consistent hash for same config', () => {
      const hash1 = configService.getConfigHash();
      const hash2 = configService.getConfigHash();
      
      expect(hash1).toBe(hash2);
    });

    it('should return different hash after config change', async () => {
      const hash1 = configService.getConfigHash();

      await configService.injectDrift({
        rule: {
          name: 'new_rule',
          source: ['any'],
          destination: ['any'],
          service: ['any'],
          action: 'allow',
          enabled: true
        }
      });

      const hash2 = configService.getConfigHash();
      expect(hash1).not.toBe(hash2);
    });
  });
});
