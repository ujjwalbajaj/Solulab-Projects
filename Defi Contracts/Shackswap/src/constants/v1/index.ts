import { Interface } from '@ethersproject/abi'
import { ChainId } from '@mukeshdas/sdkv1'
import V1_EXCHANGE_ABI from './v1_exchange.json'
import V1_FACTORY_ABI from './v1_factory.json'

const V1_FACTORY_ADDRESSES: { [chainId in ChainId]: string } = {
  [ChainId.MAINNET]: '0x75Df718fDA7D84a6a6E4d80901bb0eDC4230f6d9', // TODO
  // [ChainId.BSCTESTNET]: '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F'
  // [ChainId.BSCTESTNET]: '0xD414E85E1Ab08E20dD57786044d1554228746309' 
  [ChainId.BSCTESTNET]: '0xd3339261B1C0e12352339e9175f5240bCA86090E'
}

const V1_FACTORY_INTERFACE = new Interface(V1_FACTORY_ABI)
const V1_EXCHANGE_INTERFACE = new Interface(V1_EXCHANGE_ABI)

export { V1_FACTORY_ADDRESSES, V1_FACTORY_INTERFACE, V1_FACTORY_ABI, V1_EXCHANGE_INTERFACE, V1_EXCHANGE_ABI }
