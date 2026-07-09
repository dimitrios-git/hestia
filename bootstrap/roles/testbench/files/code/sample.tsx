import { useState } from "react";

type Props = { title: string; count?: number };

export function Counter({ title, count = 0 }: Props) {
  const [n, setN] = useState<number>(count);
  return (
    <div className="counter" onClick={() => setN(n + 1)}>
      <h1>{title}</h1>
      <span>{n === 0 ? "zero" : `${n} clicks`}</span>
    </div>
  );
}
