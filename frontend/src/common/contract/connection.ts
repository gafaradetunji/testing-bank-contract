import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider();

const signer = await provider.getSigner();

export { provider, signer };
