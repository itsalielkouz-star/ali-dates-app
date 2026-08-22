const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const WEB_DIR = path.join(__dirname, '..', 'build', 'web');
const PORT = 8080;

const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.js': 'application/javascript; charset=UTF-8',
  '.mjs': 'application/javascript; charset=UTF-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=UTF-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Odoo JSON-RPC Proxy Handler
  if (req.url.startsWith('/jsonrpc')) {
    let body = [];
    req.on('data', chunk => body.push(chunk));
    req.on('end', () => {
      const postData = Buffer.concat(body);
      const odooReq = https.request({
        hostname: 'odoo-ps-psae-ali-dates.odoo.com',
        port: 443,
        path: req.url,
        method: req.method,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': postData.length,
        }
      }, odooRes => {
        res.writeHead(odooRes.statusCode, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        odooRes.pipe(res);
      });

      odooReq.on('error', err => {
        res.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ error: err.message }));
      });

      odooReq.write(postData);
      odooReq.end();
    });
    return;
  }

  // Static File Serving
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';

  let filePath = path.join(WEB_DIR, reqPath);

  // Security check
  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // Fallback to index.html for SPA routing
      const indexPath = path.join(WEB_DIR, 'index.html');
      fs.readFile(indexPath, (idxErr, content) => {
        if (idxErr) {
          res.writeHead(404);
          res.end('Not Found');
        } else {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=UTF-8' });
          res.end(content);
        }
      });
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Ali Dates Production Web Server running on http://localhost:${PORT}`);
});
