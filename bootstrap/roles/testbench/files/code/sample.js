// TODO: builtins, template strings, operators
const MAX = 10;

export function greet(name = "world", times = 3) {
  const parts = [];
  for (let i = 0; i < times && i < MAX; i++) {
    parts.push(`hi ${name}\n`);
  }
  return parts.length === 0 ? null : parts.join("");
}

console.log(greet(process.argv[2]));
