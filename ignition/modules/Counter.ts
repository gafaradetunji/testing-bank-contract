import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MiniBankModule", (m) => {
  const counter = m.contract("MiniBank");

  // m.call(counter, "incBy", [5n]);

  return { counter };
});
