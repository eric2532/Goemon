// Mount the exported pack as one seekable file backed by bounded fetch buffers.
// Godot's browser preloader assembles a single response ArrayBuffer and copies it into MEMFS.
async function startCrossGate(engine, config, hashes, options) {
	const partSize = 64 * 1024 * 1024;
	const rangeSize = 4 * 1024 * 1024;
	const path = `${config.executable}.pck`;
	const size = config.fileSizes[path];
	const parts = new Array(Math.ceil(size / partSize));
	const cache = await globalThis.caches?.open('cross-gate-pack-v1').catch(() => null);
	let downloaded = 0;
	let nextPart = 0;
	async function matchesHash(bytes, hash) {
		const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
		return Array.from(digest, value => value.toString(16).padStart(2, '0')).join('') === hash;
	}
	async function downloadParts() {
		while (nextPart < parts.length) {
			const index = nextPart++;
			const name = `${path}.${String(index).padStart(3, '0')}`;
			const expected = Math.min(partSize, size - index * partSize);
			const hash = hashes[index];
			const cacheKey = new URL(name, location.href);
			cacheKey.searchParams.set('sha256', hash);
			const cached = await cache?.match(cacheKey).then(response => response?.arrayBuffer()).catch(() => null);
			if (cached?.byteLength === expected && await matchesHash(cached, hash)) {
				parts[index] = new Uint8Array(cached);
				downloaded += expected;
				options.onProgress(downloaded, size);
				continue;
			}
			const bytes = new Uint8Array(expected);
			let received = 0;
			while (received < expected) {
				const rangeStart = received;
				const end = Math.min(rangeStart + rangeSize, expected) - 1;
				for (let attempt = 1; ; attempt++) {
					const start = received;
					try {
						const response = await fetch(name, {
							headers: {Range: `bytes=${start}-${end}`},
							cache: 'no-store',
							signal: AbortSignal.timeout(45000),
						});
						const contentRange = response.headers.get('Content-Range');
						if (response.status !== 206 || contentRange !== `bytes ${start}-${end}/${expected}`) {
							await response.body?.cancel();
							throw new Error(`expected byte range ${start}-${end}, received HTTP ${response.status} ${contentRange || ''}`);
						}
						for await (const block of response.body) {
							if (received + block.byteLength > end + 1) throw new Error('response exceeded the requested range');
							bytes.set(block, received);
							received += block.byteLength;
						}
						if (received !== end + 1) throw new Error('incomplete response');
						break;
					} catch (error) {
						if (attempt === 4) throw new Error(`Cannot load ${name}: ${error.message}`);
						if (received > end) received = start;
						await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
					}
				}
				downloaded += end - rangeStart + 1;
				options.onProgress(downloaded, size);
			}
			if (!await matchesHash(bytes, hash)) throw new Error(`Invalid checksum for ${name}`);
			parts[index] = bytes;
			// Retain completed parts across reloads. Network streaming still works when storage is full.
			await cache?.put(cacheKey, new Response(bytes)).catch(() => {});
		}
	}

	await Promise.all([engine.init(config.executable), ...Array.from({length: 4}, downloadParts)]);
	const fs = engine.rtenv.FS;
	const file = fs.create(`/${path}`, 0o444);
	file.usedBytes = size;
	file.stream_ops = {
		llseek: file.stream_ops.llseek,
		read(_stream, buffer, offset, length, position) {
			let remaining = Math.max(0, Math.min(length, size - position));
			const count = remaining;
			while (remaining > 0) {
				const part = parts[Math.floor(position / partSize)];
				const start = position % partSize;
				const take = Math.min(part.length - start, remaining);
				buffer.set(part.subarray(start, start + take), offset);
				position += take;
				offset += take;
				remaining -= take;
			}
			return count;
		},
	};
	return engine.start({args: ['--main-pack', path, ...config.args]});
}
