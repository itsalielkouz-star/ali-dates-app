const http = require('http');
const https = require('https');

const server = http.createServer((clientReq, clientRes) => {
  clientRes.setHeader('Access-Control-Allow-Origin', '*');
  clientRes.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  clientRes.setHeader('Access-Control-Allow-Headers', '*');

  if (clientReq.method === 'OPTIONS') {
    clientRes.writeHead(200);
    clientRes.end();
    return;
  }

  let body = [];
  clientReq.on('data', chunk => body.push(chunk));
  clientReq.on('end', () => {
    const postData = Buffer.concat(body);
    const odooReq = https.request({
      hostname: 'odoo-ps-psae-ali-dates.odoo.com',
      port: 443,
      path: clientReq.url,
      method: clientReq.method,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': postData.length,
      }
    }, odooRes => {
      clientRes.writeHead(odooRes.statusCode, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      });
      odooRes.pipe(clientRes);
    });

    odooReq.on('error', err => {
      clientRes.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      clientRes.end(JSON.stringify({ error: err.message }));
    });

    odooReq.write(postData);
    odooReq.end();
  });
});

const PORT = 8081;
server.listen(PORT, () => {
  console.log(`Odoo CORS Proxy is running on http://localhost:${PORT}`);
});
