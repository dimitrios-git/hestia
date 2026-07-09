// line comment; TODO: builtins, generics, decorators
import { readFile } from "node:fs";

interface User {
  id: number;
  name: string;
}

const MAX = 0xff; // const + hex

@Component
export class Service<T extends User> {
  private items: T[] = [];

  async find(id: number, name = "x"): Promise<T | null> {
    const found = this.items.find((u) => u.id === id && u.name === name);
    console.log(`found ${found?.name ?? "none"}`);
    return found ?? null;
  }
}
