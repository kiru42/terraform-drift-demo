# Mock Panorama API

TypeScript/Express REST API simulating a Palo Alto Panorama firewall for drift detection testing.

## Features

- ✅ RESTful API for firewall config management
- ✅ In-memory config with file persistence
- ✅ Configuration hashing for drift detection
- ✅ Drift injection for testing
- ✅ Clean architecture (MVC pattern)
- ✅ Full TypeScript with strict mode
- ✅ Unit tested (Jest)
- ✅ Structured logging (Winston)

## Quick Start

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Start server
npm start
```

Server runs on `http://localhost:3000`

## API Endpoints

### GET /health

Health check endpoint.

**Response:**
```json
{
  "success": true,
  "message": "Mock Panorama API is healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "data": {
    "uptime": 123.45,
    "configHash": "abc123"
  }
}
```

### GET /config

Get current firewall configuration.

**Response:**
```json
{
  "success": true,
  "data": {
    "version": "1.0.0",
    "device": {
      "hostname": "panorama-mock",
      "model": "PA-5220"
    },
    "policies": {
      "security": [
        {
          "name": "allow_internal_web",
          "source": ["10.0.0.0/8"],
          "destination": ["any"],
          "service": ["http", "https"],
          "action": "allow",
          "enabled": true,
          "description": "Allow internal networks to access web"
        }
      ]
    },
    "metadata": {
      "lastModified": "2024-01-15T10:00:00.000Z",
      "modifiedBy": "terraform"
    }
  },
  "message": "Config hash: abc123",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### POST /config

Update firewall configuration (used by Terraform).

**Request Body:**
```json
{
  "version": "1.0.0",
  "device": { ... },
  "policies": {
    "security": [ ... ]
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Configuration updated successfully. Hash: xyz789",
  "timestamp": "2024-01-15T10:31:00.000Z"
}
```

### POST /drift

Inject drift for testing (simulate manual firewall change).

**Request Body - Add Rule:**
```json
{
  "rule": {
    "name": "rogue_rule",
    "source": ["any"],
    "destination": ["any"],
    "service": ["any"],
    "action": "allow",
    "enabled": true,
    "description": "Unauthorized rule"
  }
}
```

**Request Body - Modify First Rule:**
```json
{
  "action": "modify_first"
}
```

**Request Body - Delete Last Rule:**
```json
{
  "action": "delete_last"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Drift injected successfully. New hash: xyz789",
  "data": {
    "hash": "xyz789"
  },
  "timestamp": "2024-01-15T10:32:00.000Z"
}
```

### POST /reset

Reset configuration to default baseline.

**Response:**
```json
{
  "success": true,
  "message": "Configuration reset to default. Hash: abc123",
  "timestamp": "2024-01-15T10:33:00.000Z"
}
```

## Development

### Project Structure

```
src/
├── server.ts              # Express app entry
├── controllers/           # HTTP handlers
│   └── configController.ts
├── services/              # Business logic
│   └── configService.ts
├── types/                 # Type definitions
│   └── config.ts
└── utils/                 # Utilities
    └── logger.ts
```

### Scripts

```bash
npm start           # Start production server
npm run dev         # Start development server (auto-reload)
npm run build       # Compile TypeScript
npm test            # Run unit tests
npm run test:watch  # Run tests in watch mode
npm run test:coverage  # Generate coverage report
npm run lint        # Run ESLint
npm run clean       # Remove build artifacts
```

### Environment Variables

```bash
PORT=3000               # Server port (default: 3000)
LOG_LEVEL=info          # Log level: debug|info|warn|error
NODE_ENV=development    # Environment: development|production
```

## Testing

### Unit Tests

```bash
npm test
```

**Coverage targets:**
- Branches: 70%
- Functions: 70%
- Lines: 70%
- Statements: 70%

### Example Test

```typescript
describe('ConfigService', () => {
  it('should detect drift when rule is added', async () => {
    const original = configService.getConfigHash();
    
    await configService.injectDrift({
      rule: { /* new rule */ }
    });
    
    const updated = configService.getConfigHash();
    expect(updated).not.toBe(original);
  });
});
```

### Manual Testing

```bash
# Start server
npm start

# In another terminal
curl http://localhost:3000/health
curl http://localhost:3000/config
curl -X POST http://localhost:3000/drift \
  -H "Content-Type: application/json" \
  -d '{"action":"modify_first"}'
```

## Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────┐
│   Controllers (HTTP Layer)      │
│   • Request validation           │
│   • Response formatting          │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│   Services (Business Logic)     │
│   • Config management            │
│   • Drift injection              │
│   • Hash calculation             │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│   Data Layer (File System)      │
│   • JSON persistence             │
│   • File I/O                     │
└─────────────────────────────────┘
```

### Request Flow

```
Client Request
    ↓
Express Middleware (CORS, JSON, Logging)
    ↓
Controller (configController.ts)
    ↓
Service (configService.ts)
    ↓
File System (data/config.json)
    ↓
Response (JSON)
```

## Configuration Hashing

**Purpose:** Detect drift by comparing config hashes

**Algorithm:**
```typescript
getConfigHash(): string {
  const configStr = JSON.stringify(this.config.policies);
  return Buffer.from(configStr).toString('base64').substring(0, 16);
}
```

**Why base64?**
- Compact representation
- URL-safe characters
- Human-readable for debugging

**Truncation to 16 chars:**
- Sufficient uniqueness for demo
- Easy to read in logs
- Production would use full MD5/SHA256

## Logging

**Library:** Winston

**Log Levels:**
- `error`: Failures, exceptions
- `warn`: Drift injection, potential issues
- `info`: Normal operations, API calls
- `debug`: Detailed execution flow

**Format:**
```json
{
  "level": "info",
  "message": "Configuration updated",
  "timestamp": "2024-01-15 10:30:00",
  "service": "mock-panorama",
  "rulesCount": 2,
  "hash": "abc123"
}
```

**Configure:**
```bash
LOG_LEVEL=debug npm start
```

## Error Handling

### 400 Bad Request

Invalid configuration format.

```json
{
  "success": false,
  "error": "Invalid configuration format",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 404 Not Found

Endpoint doesn't exist.

```json
{
  "success": false,
  "error": "Endpoint not found",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 500 Internal Server Error

Server-side failure.

```json
{
  "success": false,
  "error": "Internal server error",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## TypeScript Configuration

**Strict Mode Enabled:**
- `strict: true` - All strict checks
- `noUnusedLocals: true` - No unused variables
- `noUnusedParameters: true` - No unused function params
- `noImplicitReturns: true` - All code paths return
- `noFallthroughCasesInSwitch: true` - Explicit switch breaks

**Target:** ES2022 (modern JavaScript)

**Module:** CommonJS (Node.js compatibility)

## Production Considerations

### What's Missing (Intentionally)

This is a **demo/mock** API. Production would add:

- ✅ Authentication (API keys, JWT)
- ✅ Rate limiting
- ✅ Database backend (PostgreSQL)
- ✅ Request validation (Joi/Zod)
- ✅ HTTPS/TLS
- ✅ Metrics (Prometheus)
- ✅ Health checks (liveness/readiness)
- ✅ Graceful shutdown
- ✅ Distributed tracing
- ✅ Input sanitization

### Scaling

**Current Limitations:**
- Single process
- File-based storage
- No clustering

**To Scale:**
```javascript
// Use cluster module
import cluster from 'cluster';
import os from 'os';

if (cluster.isPrimary) {
  for (let i = 0; i < os.cpus().length; i++) {
    cluster.fork();
  }
} else {
  startServer();
}
```

**Or use PM2:**
```bash
npm install -g pm2
pm2 start dist/server.js -i max
```

## Troubleshooting

### Port already in use

```bash
# Find process
lsof -ti:3000

# Kill it
kill -9 $(lsof -ti:3000)
```

### TypeScript compilation errors

```bash
npm run clean
npm install
npm run build
```

### Tests failing

```bash
# Clear Jest cache
npm test -- --clearCache

# Run with verbose output
npm test -- --verbose
```

### API not responding

```bash
# Check if server is running
curl http://localhost:3000/health

# Check logs
LOG_LEVEL=debug npm start
```

## Contributing

1. Follow TypeScript strict mode
2. Add tests for new features
3. Update API documentation
4. Run linter before committing
5. Keep controllers thin, services fat

## License

MIT

## Author

DevOps Team
