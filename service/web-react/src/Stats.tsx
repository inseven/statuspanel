import { useQuery } from "@tanstack/react-query";

function Bubble({ children }: { children: React.ReactNode }) {
  return <div className="p-4 rounded-lg bg-white">{children}</div>;
}

export function Stats() {
  const { isLoading, data, error } = useQuery({
    queryKey: ["stats"],
    queryFn: async () => {
      const resp = await fetch(
        "https://api.statuspanel.io/api/v3/service/status",
        {
          headers: {
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
      //   const resp = await fetch("/api/v3/service/status");
      return await resp.json();
    },
  });

  if (isLoading) {
    return <p>Loading...</p>;
  }

  return (
    <div className="grid gap-4 grid-cols-1 md:grid-cols-2 my-4">
      <Bubble>
        <p>3aaaa</p>
        <p>3aaa</p>
      </Bubble>
      <Bubble>
        <p className="font-bold text-2xl">0 devices</p>
      </Bubble>
      <Bubble>
        <p>3aaaa</p>
        <p>3aaaa</p>
      </Bubble>
    </div>
  );

  return (
    <ul className="">
      <li>
        <table>
          <tr>
            <th>Build Number</th>
            <td id="build-number"></td>
          </tr>
          <tr>
            <th>Date</th>
            <td id="build-date"></td>
          </tr>
          <tr>
            <th>Commit</th>
            <td id="commit"></td>
          </tr>
        </table>
      </li>
      <li>
        <p className="">
          <span id="device-count">0</span> devices
        </p>
      </li>
      <li>
        <p className="">
          <span id="status-count">0</span> images
        </p>
        <p className="">
          <span id="status-size">0</span> MB
        </p>
      </li>
    </ul>
  );
}
