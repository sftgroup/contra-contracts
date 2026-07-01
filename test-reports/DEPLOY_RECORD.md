# DEPLOY_RECORD.md — Contra AI (v2026-07-02)

## 部署时间线

| # | 时间 | 项目 | 详情 |
|---|------|------|------|
| 0 | 2026-06-29 ~23:00 | 初始部署 | 4 链合约 + 前端 + Relay |
| 1 | 2026-06-29 ~23:50 | Treasury 修复 | 新 Treasury 0x6d250... |
| 2 | 2026-06-30 00:50 | ContraNFT v2 部署 | 新增 setBaseURI 功能 |
| 3 | 2026-07-01 13:37 | ContraNFT v3 部署 (ba204d) | Timelock 安全加固，mintPrice=10000 USDC |
| 4 | 2026-07-01 23:45 | ContraNFT v3 部署 (b5fa28) | mintPrice 修正为 10000 USDC (transferFrom) |
| 5 | 2026-07-02 00:40 | **ContraNFT v3 Final** | mintPrice=1, tUSDC, safeTransferFrom |

---

## ContraNFT v3 Final (ETH Sepolia) — 当前生产版本

| 属性 | 值 |
|------|-----|
| **合约名称** | ContraNFT v3 |
| **合约地址** | `0xF2eAF1048090d40d7035FFC81541254f3cA9dD91` |
| **网络** | Sepolia Testnet (11155111) |
| **部署者** | Owner `0x0C5D732F9f70D4A192e86E3B3FCDFf5797D2638d` |
| **部署 nonce** | 127 |
| **部署 txHash** | `0x00c54c95456f84a6f8bd1711f180b930863dc6277095c430d199723113163c00` |
| **部署时间** | 2026-07-02 00:38 GMT+8 |
| **ABI 路径** | `contra-frontend/contracts/out/ContraNFT.sol/ContraNFT.json` |
| **代码源路径** | `contra-frontend/contracts/src/ContraNFT.sol` |
| **GitHub** | `sftgroup/contra-contracts` (public) |
| **本地同步状态** | ✅ |
| **v3 功能** | 2-step Treasury/PaymentToken, CEI reentrancy hardening, paused 语义扩展 |

### 构造函数参数
| 参数 | 值 |
|------|-----|
| name | Contra AI |
| symbol | CONTRA |
| paymentToken (tUSDC) | `0x286D18bc7aFa5DC8Af7FdF93fAb544849E972479` |
| mintPrice | 1 (0.000001 tUSDC) |
| maxSupply | 100 |
| treasury | `0x6d250E302b8217FEe26e41F150978769b440E29A` |
| beneficiary | `0x61317041E0c17f5A7bf934e46f07Db1C6d534ccF` |

### v3 Final 部署步骤 (全部 on-chain)
| Step | 操作 | txHash | nonce | 状态 |
|------|------|--------|-------|------|
| 1 | 部署 ContraNFT | `0x00c54c...` | 127 | ✅ |
| 2 | setBaseURI | publicnode, status 1 | 128 | ✅ |
| 3 | Treasury.setContraNFT | publicnode, status 1 | 129 | ✅ |
| 4 | USDC approve | publicnode, status 1 | 130 | ✅ |
| 5 | Mint #1 | `0xcb84b2...` | 131 | ✅ |
| 6 | Mint #2 | publicnode, status 1 | 132 | ✅ |

### 前端同步
| 文件 | 变更 | 服务器 |
|------|------|--------|
| `mint.html` | CHAIN_CONFIG eth contract: `0xeFA6...` → `0xF2eAF...` | 43.159.39.85 |
| `contra-contracts.js` | 无需改（动态读取 CHAIN_CONFIG） | 43.159.39.85 |

### 已废弃合约
| 版本 | 地址 | 原因 |
|------|------|------|
| v1 | `0xeFA6EF399797C63F166376eD200A899526a95e9b` | 无 setBaseURI |
| v2 | `0x5Dc8D77D6034aA1F55b8f0D84245a2249076B0e6` | 无 Timelock |
| v3 (ba204d) | `0xba204d970267F18f8f028F2b37f78FFea5A004F1` | mintPrice=10000 USDC，owner 余额不足 |
| v3 (b5fa28) | `0xb5fa285930783d8b07c1fd88a083687b52a71d46` | transferFrom 改为非安全版本 |
| v3 (9b0013) | `0x9b0013073BB95FF569454ba35d70186DD764d78b` | transferFrom 改为非安全版本 |

---

## 中心化部署

| 服务 | 位置 | 详情 |
|------|------|------|
| 前端 | `43.159.39.85:3080` | Docker nginx:alpine, mount `/root/contra-frontend/` |
| Relay | `43.159.39.85:3001` | Docker node:20-alpine, 代码 `/home/ubuntu/contra-frontend/relay/` |
| Relay LevelDB | `/home/ubuntu/contra-relay-data/` | 邀请数据库 |

### 配置更新记录
| 日期 | 文件 | 变更 |
|------|------|------|
| 07-02 00:43 | mint.html | eth contract: 0xeFA6... → 0xF2eAF... |
| 07-02 00:30 | Treasury | setContraNFT: 0x9b0013... → 0xF2eAF... |
| 06-30 00:50 | assets/index-DncBfF8p.js | nftAddress → 0x5Dc8D... |
| 06-30 00:40 | relay/src/config.js | ETH contraNFT: 0xF9c536... → 0xeFA6E... → 0x5Dc8D... |

---

## 相关合约地址

| 合约 | ETH Sepolia |
|------|------------|
| **ContraNFT v3 (current)** | `0xF2eAF1048090d40d7035FFC81541254f3cA9dD91` |
| Treasury | `0x6d250E302b8217FEe26e41F150978769b440E29A` |
| tUSDC | `0x286D18bc7aFa5DC8Af7FdF93fAb544849E972479` |
| Owner | `0x0C5D732F9f70D4A192e86E3B3FCDFf5797D2638d` |
| Beneficiary | `0x61317041E0c17f5A7bf934e46f07Db1C6d534ccF` |
