import { Request, Response } from 'express';
import configService from '../services/configService';
import { FirewallConfig, DriftEvent, ApiResponse } from '../types/config';
import logger from '../utils/logger';

/**
 * Get current firewall configuration
 */
export const getConfig = async (
  _req: Request,
  res: Response<ApiResponse<FirewallConfig>>
): Promise<void> => {
  try {
    const config = configService.getConfig();
    const hash = configService.getConfigHash();

    logger.info('Configuration retrieved', { hash });

    res.json({
      success: true,
      data: config,
      message: `Config hash: ${hash}`,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Failed to get configuration', { error });
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      timestamp: new Date().toISOString()
    });
  }
};

/**
 * Update firewall configuration (used by Terraform)
 */
export const updateConfig = async (
  req: Request<unknown, unknown, FirewallConfig>,
  res: Response<ApiResponse>
): Promise<void> => {
  try {
    const newConfig = req.body;

    // Basic validation
    if (!newConfig || !newConfig.policies || !newConfig.policies.security) {
      res.status(400).json({
        success: false,
        error: 'Invalid configuration format',
        timestamp: new Date().toISOString()
      });
      return;
    }

    await configService.updateConfig(newConfig);
    const hash = configService.getConfigHash();

    logger.info('Configuration updated via API', { 
      rulesCount: newConfig.policies.security.length,
      hash 
    });

    res.json({
      success: true,
      message: `Configuration updated successfully. Hash: ${hash}`,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Failed to update configuration', { error });
    res.status(500).json({
      success: false,
      error: 'Failed to update configuration',
      timestamp: new Date().toISOString()
    });
  }
};

/**
 * Inject drift (simulate manual firewall change)
 */
export const injectDrift = async (
  req: Request<unknown, unknown, DriftEvent>,
  res: Response<ApiResponse>
): Promise<void> => {
  try {
    const driftEvent = req.body;

    await configService.injectDrift(driftEvent);
    const hash = configService.getConfigHash();

    logger.warn('Drift injected via API', { driftEvent, hash });

    res.json({
      success: true,
      message: `Drift injected successfully. New hash: ${hash}`,
      data: { hash },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Failed to inject drift', { error });
    res.status(500).json({
      success: false,
      error: 'Failed to inject drift',
      timestamp: new Date().toISOString()
    });
  }
};

/**
 * Reset configuration to default
 */
export const resetConfig = async (
  _req: Request,
  res: Response<ApiResponse>
): Promise<void> => {
  try {
    await configService.reset();
    const hash = configService.getConfigHash();

    logger.info('Configuration reset to default', { hash });

    res.json({
      success: true,
      message: `Configuration reset to default. Hash: ${hash}`,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Failed to reset configuration', { error });
    res.status(500).json({
      success: false,
      error: 'Failed to reset configuration',
      timestamp: new Date().toISOString()
    });
  }
};

/**
 * Health check endpoint
 */
export const healthCheck = (_req: Request, res: Response): void => {
  res.json({
    success: true,
    message: 'Mock Panorama API is healthy',
    timestamp: new Date().toISOString(),
    data: {
      uptime: process.uptime(),
      configHash: configService.getConfigHash()
    }
  });
};
