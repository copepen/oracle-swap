import React, {useEffect, useState} from "react"
import "./App.css"
import Web3 from "web3"
import {BigNumber} from "ethers"
import {TokenConfig, numberToTokenQty, ChainState, tokenQtyToNumber} from "./utils"
import IPythAbi from "@pythnetwork/pyth-sdk-solidity/abis/IPyth.json"
import OracleSwapAbi from "./abi/OracleSwapAbi.json"
import {approveToken, getApprovedQuantity} from "./erc20"
import {EvmPriceServiceConnection} from "@pythnetwork/pyth-evm-js"

/**
 * The AddOrRemoveLiquidity component lets users add/remove a quantity of the base token or quote token to get swap fees.
 */
export function AddOrRemoveLiquidity(props: {
  web3: Web3 | undefined
  account: string | null
  underlyingToken: TokenConfig
  lpToken: TokenConfig
  baseToken: TokenConfig
  quoteToken: TokenConfig
  priceServiceUrl: string
  pythContractAddress: string
  swapContractAddress: string
  chainState: ChainState | undefined
}) {
  const [isAdd, setIsAdd] = useState<boolean>(true)
  const [isApproving, setIsApproving] = useState<boolean>(false)
  const [isLoading, setIsLoading] = useState<boolean>(false)
  const [tokenAmount, setTokenAmount] = useState<string>("0")
  const [underlyingTokenAllowance, setUnderlyingTokenAllowance] = useState<BigNumber>(BigNumber.from("0"))
  const [lpTokenAllowance, setLpTokenAllowance] = useState<BigNumber>(BigNumber.from("0"))

  const tokenAmountInWei = numberToTokenQty(tokenAmount, props.underlyingToken.decimals)
  const underlyingTokenApproved = underlyingTokenAllowance.gte(tokenAmountInWei)
  const lpTokenApproved = lpTokenAllowance.gte(tokenAmountInWei)
  const isApproved = isAdd ? underlyingTokenApproved : lpTokenApproved

  useEffect(() => {
    async function helper() {
      if (props.web3 !== undefined && props.account !== null) {
        setUnderlyingTokenAllowance(
          await getApprovedQuantity(
            props.web3!,
            props.underlyingToken.erc20Address,
            props.account!,
            props.swapContractAddress
          )
        )
        setLpTokenAllowance(
          await getApprovedQuantity(props.web3!, props.lpToken.erc20Address, props.account!, props.swapContractAddress)
        )
      } else {
        setUnderlyingTokenAllowance(BigNumber.from("0"))
        setLpTokenAllowance(BigNumber.from("0"))
      }
    }

    helper()
    const interval = setInterval(helper, 3000)

    return () => {
      clearInterval(interval)
    }
  }, [props.web3, props.account, props.swapContractAddress])

  const onChangeTokenAmount = (event: any) => {
    setTokenAmount(event.target.value)
  }

  const onApprove = async () => {
    setIsApproving(true)

    try {
      if (isAdd) {
        await approveToken(props.web3!, props.underlyingToken.erc20Address, props.account!, props.swapContractAddress)
      } else {
        await approveToken(props.web3!, props.lpToken.erc20Address, props.account!, props.swapContractAddress)
      }
    } catch (err) {
      console.log("Approve error: ", err)
    }

    setIsApproving(false)
  }

  const onSubmit = async () => {
    setIsLoading(true)

    try {
      if (isAdd) {
        await sendAddLiquidityTx(
          props.web3!,
          props.priceServiceUrl,
          props.baseToken.pythPriceFeedId,
          props.quoteToken.pythPriceFeedId,
          props.pythContractAddress,
          props.swapContractAddress,
          props.account!,
          props.underlyingToken.erc20Address,
          tokenAmountInWei
        )
      } else {
        await sendRemoveLiquidityTx(
          props.web3!,
          props.priceServiceUrl,
          props.baseToken.pythPriceFeedId,
          props.quoteToken.pythPriceFeedId,
          props.pythContractAddress,
          props.swapContractAddress,
          props.account!,
          props.underlyingToken.erc20Address,
          tokenAmountInWei
        )
      }
    } catch (err) {
      console.log("Add/Remove liquidity error: ", err)
    }

    setIsLoading(false)
  }

  return (
    <div style={{minWidth: "350px"}}>
      <h3>Add/remove liquidity with {props.underlyingToken.name}</h3>
      <div className="tab-header">
        <div className={`tab-item ${isAdd ? "active" : ""}`} onClick={() => setIsAdd(true)}>
          Add
        </div>
        <div className={`tab-item ${!isAdd ? "active" : ""}`} onClick={() => setIsAdd(false)}>
          Remove
        </div>
      </div>
      <div className="tab-content">
        <div>
          <div style={{display: "flex", gap: "8px"}}>
            <span>{isAdd ? "Add" : "Remove"}</span>
            <div style={{display: "flex", flexDirection: "column", justifyContent: "end"}}>
              <input
                style={{margin: 0, marginTop: "-4px"}}
                type="text"
                name="base"
                value={tokenAmount}
                onChange={(event) => {
                  onChangeTokenAmount(event)
                }}
              />
              <span style={{fontSize: "12px"}}>
                {isAdd ? (
                  <>
                    {`${props.underlyingToken.name} balance: `}
                    {`${tokenQtyToNumber(
                      (props.underlyingToken.erc20Address === props.baseToken.erc20Address
                        ? props?.chainState?.accountBaseBalance
                        : props.chainState?.accountQuoteBalance) || BigNumber.from(0),
                      props.underlyingToken.decimals
                    )}`}
                  </>
                ) : (
                  <>
                    {`LP balance: `}
                    {`${tokenQtyToNumber(
                      props.chainState?.accountLpBalance || BigNumber.from(0),
                      props.lpToken.decimals
                    )}`}
                  </>
                )}
              </span>
            </div>
            <span>{isAdd ? props.underlyingToken.name : "LP"}</span>
          </div>

          <div className={"swap-steps"}>
            {props.account === null || props.web3 === undefined ? (
              <div>Connect your wallet to swap</div>
            ) : (
              <div style={{display: "flex", gap: "12px"}}>
                <div>
                  <span>1.</span>
                  <button onClick={onApprove} disabled={isApproved || isApproving}>
                    {isApproving ? "Approving..." : `Approve ${isAdd ? props.underlyingToken.name : "LP"}`}
                  </button>
                </div>
                <div>
                  <span>2.</span>
                  <button onClick={onSubmit} disabled={!isApproved || Number(tokenAmount) === 0 || isLoading}>
                    {isLoading ? "Loading..." : "Submit"}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

async function sendAddLiquidityTx(
  web3: Web3,
  priceServiceUrl: string,
  baseTokenPriceFeedId: string,
  quoteTokenPriceFeedId: string,
  pythContractAddress: string,
  swapContractAddress: string,
  sender: string,
  tokenAddress: string,
  tokenAmount: BigNumber
) {
  const pythPriceService = new EvmPriceServiceConnection(priceServiceUrl)
  const priceFeedUpdateData = await pythPriceService.getPriceFeedsUpdateData([
    baseTokenPriceFeedId,
    quoteTokenPriceFeedId,
  ])

  const pythContract = new web3.eth.Contract(IPythAbi as any, pythContractAddress)

  const updateFee = await pythContract.methods.getUpdateFee(priceFeedUpdateData).call()

  const swapContract = new web3.eth.Contract(OracleSwapAbi as any, swapContractAddress)

  await swapContract.methods
    .addLiquidity(tokenAddress, tokenAmount, priceFeedUpdateData)
    .send({value: updateFee, from: sender})
}

async function sendRemoveLiquidityTx(
  web3: Web3,
  priceServiceUrl: string,
  baseTokenPriceFeedId: string,
  quoteTokenPriceFeedId: string,
  pythContractAddress: string,
  swapContractAddress: string,
  sender: string,
  tokenAddress: string,
  tokenAmount: BigNumber
) {
  const pythPriceService = new EvmPriceServiceConnection(priceServiceUrl)
  const priceFeedUpdateData = await pythPriceService.getPriceFeedsUpdateData([
    baseTokenPriceFeedId,
    quoteTokenPriceFeedId,
  ])

  const pythContract = new web3.eth.Contract(IPythAbi as any, pythContractAddress)

  const updateFee = await pythContract.methods.getUpdateFee(priceFeedUpdateData).call()

  const swapContract = new web3.eth.Contract(OracleSwapAbi as any, swapContractAddress)

  await swapContract.methods
    .removeLiquidity(tokenAmount, tokenAddress, priceFeedUpdateData)
    .send({value: updateFee, from: sender})
}
