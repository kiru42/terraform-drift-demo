/**
 * Firewall Policy Rule
 */
export interface PolicyRule {
  name: string;
  source: string[];
  destination: string[];
  service: string[];
  action: 'allow' | 'deny' | 'drop';
  enabled: boolean;
  description?: string;
}

/**
 * Firewall Configuration
 */
export interface FirewallConfig {
  version: string;
  device: {
    hostname: string;
    model: string;
  };
  policies: {
    security: PolicyRule[];
  };
  metadata: {
    lastModified: string;
    modifiedBy: string;
  };
}

/**
 * Drift Event
 */
export interface DriftEvent {
  rule?: PolicyRule;
  action?: string;
  timestamp?: string;
}

/**
 * API Response
 */
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
  timestamp: string;
}
