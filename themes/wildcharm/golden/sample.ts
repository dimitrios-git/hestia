// Golden sample — TypeScript. Exercises every syntax role in palette.yml.
// TODO: keep this file stable; coherence checks diff renders of THIS content.

import { readFile } from "node:fs/promises";

const RETRY_LIMIT = 3;
const GREETING = `hello, ${process.env.USER ?? "world"}\n`;
const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;

type Palette = Record<string, string>;

interface Loader<T> {
  load(path: string): Promise<T>;
  retries?: number;
}

export class PaletteLoader implements Loader<Palette> {
  private cache: Palette | null = null;

  constructor(public readonly path: string) {}

  async load(): Promise<Palette> {
    if (this.cache !== null) return this.cache;
    for (let attempt = 1; attempt <= RETRY_LIMIT; attempt++) {
      try {
        const raw = await readFile(this.path, "utf-8");
        this.cache = JSON.parse(raw) as Palette;
        return this.cache;
      } catch (err) {
        if (attempt === RETRY_LIMIT) throw err;
      }
    }
    throw new Error(`unreachable: ${this.path}`);
  }
}
