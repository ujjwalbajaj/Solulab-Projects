import { ChainId } from '@mukeshdas/sdkv1'
import MULTICALL_ABI from './abi.json'

const MULTICALL_NETWORKS: { [chainId in ChainId]: string } = {
  [ChainId.MAINNET]: '0x27bE26891F160F086E58D4B6991c9760F961390a', // TODO
  // [ChainId.BSCTESTNET]: '0x301907b5835a2d723Fe3e9E8C5Bc5375d5c1236A'
  [ChainId.BSCTESTNET]: '0x551aA1715ae9488e24f17e13f1034c403a8b71e0'
}

export { MULTICALL_ABI, MULTICALL_NETWORKS }
