import { createServer } from 'node:http';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const dataDirectory = join(root, '..', 'data');
const dataFile = join(dataDirectory, 'portfolio.json');
const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? '127.0.0.1';
const maxBodyBytes = 16 * 1024;
let writeQueue = Promise.resolve();

async function readPortfolio() {
  try {
    const parsed = JSON.parse(await readFile(dataFile, 'utf8'));
    if (!Array.isArray(parsed.assets)) throw new Error('Invalid portfolio file');
    return parsed.assets;
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
}

async function savePortfolio(assets) {
  const operation = writeQueue.then(async () => {
    await mkdir(dataDirectory, { recursive: true });
    const temporaryFile = `${dataFile}.tmp`;
    await writeFile(temporaryFile, `${JSON.stringify({ assets }, null, 2)}\n`, 'utf8');
    await rename(temporaryFile, dataFile);
  });
  writeQueue = operation.catch(() => {});
  await operation;
}

async function readJsonBody(request) {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > maxBodyBytes) {
      const error = new Error('O corpo da requisição excede o limite permitido.');
      error.status = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  if (bytes === 0) return {};
  try {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (body === null || Array.isArray(body) || typeof body !== 'object') {
      throw new Error('O corpo deve ser um objeto JSON.');
    }
    return body;
  } catch {
    const error = new Error('Envie um objeto JSON válido.');
    error.status = 400;
    throw error;
  }
}

function validateAsset(body, symbolFromPath = null) {
  const symbol = String(symbolFromPath ?? body.symbol ?? '').trim().toUpperCase();
  if (!symbol || symbol.length > 30 || /[,\s\x00-\x1f\x7f]/.test(symbol)) {
    const error = new Error('Informe um símbolo de criptomoeda válido.');
    error.status = 400;
    throw error;
  }

  const quantity = body.quantity;
  if (typeof quantity !== 'number' || !Number.isFinite(quantity) || quantity <= 0) {
    const error = new Error('A quantidade deve ser um número positivo e finito.');
    error.status = 400;
    throw error;
  }

  const coinName = typeof body.coinName === 'string' && body.coinName.trim()
    ? body.coinName.trim().slice(0, 80)
    : symbol;
  let imageUrl = null;
  if (body.imageUrl != null && body.imageUrl !== '') {
    try {
      const parsed = new URL(body.imageUrl);
      if (parsed.protocol !== 'https:') throw new Error();
      imageUrl = parsed.toString();
    } catch {
      const error = new Error('A imagem deve usar um endereço HTTPS válido.');
      error.status = 400;
      throw error;
    }
  }
  return { symbol, coinName, quantity, imageUrl };
}

function send(response, status, payload) {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify(payload));
}

const server = createServer(async (request, response) => {
  if (request.method === 'OPTIONS') {
    send(response, 204, {});
    return;
  }

  try {
    const url = new URL(request.url, `http://${request.headers.host ?? 'localhost'}`);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    if (request.method === 'GET' && path === '/api/health') {
      send(response, 200, { status: 'ok', service: 'CryptoHub API' });
      return;
    }
    if (request.method === 'GET' && path === '/api/portfolio') {
      send(response, 200, { assets: await readPortfolio() });
      return;
    }
    if (request.method === 'POST' && path === '/api/portfolio/assets') {
      const asset = validateAsset(await readJsonBody(request));
      const assets = await readPortfolio();
      if (assets.some((item) => item.symbol === asset.symbol)) {
        send(response, 409, { error: 'Este ativo já está na carteira. Use PUT para atualizá-lo.' });
        return;
      }
      assets.push(asset);
      await savePortfolio(assets);
      send(response, 201, { asset });
      return;
    }

    const assetPath = path.match(/^\/api\/portfolio\/assets\/([^/]+)$/);
    if (assetPath) {
      const symbol = decodeURIComponent(assetPath[1]).toUpperCase();
      const assets = await readPortfolio();
      const index = assets.findIndex((item) => item.symbol === symbol);
      if (request.method === 'PUT') {
        const asset = validateAsset(await readJsonBody(request), symbol);
        if (index < 0) {
          assets.push(asset);
        } else {
          assets[index] = asset;
        }
        await savePortfolio(assets);
        send(response, index < 0 ? 201 : 200, { asset });
        return;
      }
      if (request.method === 'DELETE') {
        if (index < 0) {
          send(response, 404, { error: 'Ativo não encontrado na carteira.' });
          return;
        }
        assets.splice(index, 1);
        await savePortfolio(assets);
        send(response, 200, { removed: symbol });
        return;
      }
    }
    send(response, 404, { error: 'Rota não encontrada.' });
  } catch (error) {
    console.error(error);
    send(response, error.status ?? 500, {
      error: error.status ? error.message : 'Não foi possível processar a requisição.',
    });
  }
});

server.listen(port, host, () => {
  console.log(`CryptoHub API disponível em http://localhost:${port}`);
});
