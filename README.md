# OpenClaw Session Lock Cleanup

自动清理 OpenClaw 会话锁文件的脚本，防止通道因锁文件泄漏而假死。

## 🐛 问题描述

### 什么是 Session Lock 泄漏？

当 OpenClaw 的 agent 运行超时或异常终止时，有时会留下孤立的 `.jsonl.lock` 文件，但没有对应的 `.jsonl` 转录文件。这会导致：

- ❌ 网关静默丢弃所有后续传入的消息
- ❌ 通道永久死亡，直到手动删除锁文件
- ❌ 没有日志记录，难以排查问题

### 根本原因

GitHub Issue [#59983](https://github.com/openclaw/openclaw/issues/59983) 和 PR [#60015](https://github.com/openclaw/openclaw/pull/60015) 详细描述了这个问题：

1. **锁泄漏**：agent 超时后，清理步骤中的异常导致 `sessionLock.release()` 未执行
2. **孤儿检测失败**：Linux 上存在检测同进程孤儿锁的 bug
3. **静默丢弃**：后续消息被静默丢弃，没有日志

## 📋 脚本功能

### 自动清理异常锁文件

- ✅ 清理孤立的 `.lock` 文件（没有对应的 `.jsonl`）
- ✅ 清理超过 5 分钟的孤儿锁文件
- ✅ 保留正常的锁文件
- ✅ 详细的日志记录
- ✅ 每次执行后统计清理结果

### 使用场景

1. **定时任务**：每 30 分钟自动检查并清理
2. **手动触发**：当通道出现假死时手动清理
3. **系统监控**：监控锁文件异常数量

## 🚀 快速开始

### 1. 获取脚本

从 GitHub 下载：
```bash
git clone https://github.com/linshuikeji/openclaw-session-lock-cleanup.git
```

### 2. 安装依赖

无依赖，纯 Bash 脚本。

### 3. 配置定时任务

编辑 crontab：
```bash
crontab -e
```

添加以下行（每 30 分钟执行）：
```cron
0 */30 * * * cd /home/linshui/.openclaw/workspace && /home/linshui/.openclaw/workspace/cleanup-session-locks.sh >> /tmp/cleanup-locks.log 2>&1
```

### 4. 手动测试

运行脚本：
```bash
/home/linshui/.openclaw/workspace/cleanup-session-locks.sh
```

查看日志：
```bash
tail -f /tmp/cleanup-locks.log
```

## 📖 使用说明

### 脚本参数

无参数，自动执行。

### 输出日志

日志文件：`/tmp/cleanup-locks.log`

日志格式：
```
[2026-04-03 16:22:22] 开始清理会话锁文件...
[2026-04-03 16:22:22] 发现孤立锁文件：/path/to/session.jsonl.lock
[2026-04-03 16:22:22] 已删除孤立锁文件：session-id
[2026-04-03 16:22:22] 清理完成！
[2026-04-03 16:22:22]   - 清理孤立锁文件：1 个
[2026-04-03 16:22:22]   - 清理孤儿锁文件：0 个
[2026-04-03 16:22:22]   - 保留正常锁文件：0 个
```

### 监控告警

如果检测到异常锁文件被清理，脚本会发送警告：
```
⚠️  检测到 1 个异常锁文件已被清理！
如果通道出现假死，可能是 session 超时导致的锁泄漏。
```

## 🔍 工作原理

### 清理逻辑

1. **遍历所有 `.lock` 文件**
2. **检查对应的 `.jsonl` 文件是否存在**
   - 如果不存在 → 孤立锁文件 → 删除
   - 如果存在 → 检查锁文件年龄
3. **检查孤儿锁文件**
   - 如果锁文件超过 5 分钟且 session 已过期 → 删除
   - 否则 → 保留

### 时间阈值

- **孤儿锁文件**：超过 5 分钟（300 秒）
- **执行频率**：建议每 30 分钟一次

## 🛠️ 故障排除

### 常见问题

#### Q: 脚本不执行？
A: 检查 cron 任务是否设置正确：
```bash
crontab -l | grep cleanup
```

#### Q: 日志文件不存在？
A: 确保脚本有执行权限：
```bash
chmod +x cleanup-session-locks.sh
```

#### Q: 清理了太多文件？
A: 检查是否真的有 session 异常。如果有大量清理，可能需要排查 agent 超时问题。

#### Q: 如何手动清理？
A: 运行脚本：
```bash
./cleanup-session-locks.sh
```

### 日志分析

查看最近的清理记录：
```bash
tail -50 /tmp/cleanup-locks.log
```

查看历史清理记录：
```bash
cat /tmp/cleanup-locks.log
```

## 📊 监控指标

### 正常情况

- 清理数量为 0
- 没有警告信息
- 日志正常记录

### 异常情况

- 检测到孤立锁文件
- 检测到孤儿锁文件
- 清理数量 > 0

### 需要关注的情况

- **连续多次清理**：可能 agent 频繁超时
- **清理数量激增**：可能存在系统异常
- **通道假死**：检查是否有孤立的锁文件

## 🔗 相关资源

### GitHub 链接

- **仓库**：https://github.com/linshuikeji/openclaw-session-lock-cleanup
- **OpenClaw Issue**：https://github.com/openclaw/openclaw/issues/59983
- **OpenClaw PR**：https://github.com/openclaw/openclaw/pull/60015

### 建议的长期方案

1. **等待 PR #60015 合并**：从根源解决锁泄漏问题
2. **升级 OpenClaw**：升级到包含修复的最新版本
3. **使用此脚本**：作为临时解决方案

## 📝 License

MIT License

## 👤 作者

linshuikeji

## 🙏 致谢

感谢 OpenClaw 社区提供的 Issue 和 PR，帮助我们理解并解决这个问题。

---

**注意**：此脚本是临时解决方案。建议等待 OpenClaw 官方修复合并后升级系统。
