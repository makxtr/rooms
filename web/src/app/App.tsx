import { useQuery } from "@tanstack/react-query";
import { api } from "../api/client";

function BackendStatus() {
  const health = useQuery({
    queryKey: ["health"],
    queryFn: async () => {
      const { data, error } = await api.GET("/health");
      if (error) throw new Error(error.title);
      return data;
    },
  });

  if (health.isPending) return <p>backend: …</p>;
  if (health.isError) return <p>backend: unavailable</p>;
  return <p>backend: {health.data.status}</p>;
}

export function App() {
  return (
    <main>
      <h1>Rooms</h1>
      <BackendStatus />
    </main>
  );
}
