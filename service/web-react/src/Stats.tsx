function Bubble({ children }) {
  return <div className="p-4 rounded-lg bg-white">{children}</div>;
}

export function Stats() {
  return (
    <div className="grid gap-8 grid-cols-1 md:grid-cols-2">
      <p>1</p>
      <p>2</p>
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
