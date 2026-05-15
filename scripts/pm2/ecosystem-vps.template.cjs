/**
 * PM2 ecosystem for VPS Node apps (Render-like auto-restart).
 * Copy sections you need to each project's deploy/ecosystem.config.cjs
 * or merge into one file at /var/www/ecosystem.config.cjs
 *
 * pm2 start ecosystem.config.cjs
 * pm2 save
 * pm2 startup systemd
 */

module.exports = {
  apps: [
    {
      name: 'ocean-school',
      cwd: '/var/www/ocean-school',
      script: 'server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 50,
      min_uptime: '10s',
      max_memory_restart: '512M',
      env: { NODE_ENV: 'production', PORT: 3001 },
    },
    {
      name: 'kitchen',
      cwd: '/var/www/kitchen',
      script: 'server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 50,
      min_uptime: '10s',
      max_memory_restart: '512M',
      env: { NODE_ENV: 'production', PORT: 3002 },
    },
    {
      name: 'scis-gate-api',
      cwd: '/var/www/scis-gate/backend',
      script: 'server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 50,
      min_uptime: '10s',
      max_memory_restart: '512M',
      env: { NODE_ENV: 'production', PORT: 3003 },
    },
    // SCIS pickup can stay on systemd (scis.service) OR move here on port 4000:
    // {
    //   name: 'scis-pickup',
    //   cwd: '/var/www/scis/app/backend',
    //   script: 'server.js',
    //   instances: 1,
    //   autorestart: true,
    //   max_memory_restart: '768M',
    //   env_file: '/var/www/scis/app/backend/.env',
    // },
  ],
};
