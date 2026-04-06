import express, { Express } from 'express';
import cors from 'cors';
import morgan from 'morgan';
import configService from './services/configService';
import * as configController from './controllers/configController';
import logger from './utils/logger';

const app: Express = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('combined', {
  stream: {
    write: (message: string) => logger.info(message.trim())
  }
}));

// Routes
app.get('/health', configController.healthCheck);
app.get('/config', configController.getConfig);
app.post('/config', configController.updateConfig);
app.post('/drift', configController.injectDrift);
app.post('/reset', configController.resetConfig);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// Initialize and start server
const startServer = async () => {
  try {
    await configService.init();
    
    app.listen(PORT, () => {
      logger.info(`🔥 Mock Panorama API listening on port ${PORT}`);
      logger.info(`Health check: http://localhost:${PORT}/health`);
      logger.info(`Config endpoint: http://localhost:${PORT}/config`);
    });
  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
};

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

startServer();

export default app;
