# frozen_string_literal: true

module Curriculum
  # Pure, deterministic content-quality checks for canonical chapter specs.
  # These checks intentionally target known placeholder templates; they are not
  # a substitute for human editorial review.
  module SpecQuality
    GENERIC_BUILD_PHRASES = [
      "最小可运行工件",
      "最小可运行成果"
    ].freeze

    BUILD_ACTIONS = %w[
      实现 编写 创建 构建 配置 部署 设计 修复 重构 生成 运行 完成 产出
    ].freeze

    BUILD_ARTIFACTS = %w[
      程序 脚本 类 方法 模块 组件 页面 表单 接口 API 服务 查询 Schema 数据表
      测试 用例 配置 镜像 容器 流水线 模型 数据集 Notebook Agent 状态图 报告
      命令 请求 响应 工单 文件 清单 策略 规则 索引 队列 契约 制品 演练 补丁
      应用 项目 系统
    ].freeze

    FAILURE_TOKENS = %w[
      编译错误 类型错误 NullPointerException 空指针 数组越界 死锁 数据竞争 竞态覆盖 超时
      取消失效 内存泄漏 编码乱码 路径不存在 权限拒绝 认证绕过 授权绕过 越权 跨租户
      SQL注入 XSS CSRF SSRF 事务未回滚 锁等待 重复消息 乱序消息 幂等冲突 缓存污读
      水合不一致 响应式失效 闭包捕获错误 事件循环阻塞 网络超时 HTTP状态码错误 CORS预检失败 预检状态码错误
      Cookie泄漏 布局溢出 焦点丢失 无障碍名称缺失 路由循环 非法状态迁移 Future未取消
      Stream未订阅 Isolate消息丢失 mounted后更新 未捕获异常 导入循环 JSON解析失败 序列化字段丢失
      shape不匹配 梯度消失 梯度爆炸 过拟合 欠拟合 幻觉 检索无结果 引用不存在 ACL绕过
      提示注入 工具参数越权 MCP越权 容器启动失败 端口冲突 DNS解析失败 TLS证书失效
      迁移失败 备份不可恢复 恢复超时 部署失败 告警缺失 日志缺失 指标异常 数据丢失
      解析失败 连接失败 断言失败 整数溢出 精度丢失 边界偏移
      非穷尽 状态拼错 复杂度热点 重复排序
    ].freeze

    FAILURE_SIGNAL_TOKENS = %w[
      错误 失败 缺失 不一致 遗漏 冲突 异常 越界 不匹配 泄露 无效 漂移
      覆盖 阻塞 乱码 不存在 意外 误用 误记 误写 误判 丢失 漏掉 截断 溢出
      歧义 无限 静默 掉线 损坏 不可恢复 未执行 未生效 未关闭 未取消 未回滚
      未初始化 混为一谈 不可达 不正确 不合法 非法 偏差 抖动 退化
    ].freeze

    ORACLE_TOKENS = %w[
      退出码 状态码 断言 预期 等于 不等于 包含 不包含 Tests\ run Failures Errors
      行数 数量 计数 响应体 日志字段 快照 diff 校验和 digest 哈希 拒绝 超时 回滚
      恢复 无重复 唯一 顺序 延迟 内存上限 CPU 输出 返回值 通过 失败
    ].freeze

    module_function

    def outcome_issue(outcome, chapter)
      return nil unless outcome.is_a?(Hash)

      text = outcome["text"].to_s
      case outcome["id"]
      when "build"
        return "build outcome uses a known placeholder phrase" if GENERIC_BUILD_PHRASES.any? { |phrase| text.include?(phrase) }
        return "build outcome must name a concrete action" unless contains_any?(text, BUILD_ACTIONS)
        return "build outcome must name a concrete artifact" unless contains_any?(text, BUILD_ARTIFACTS)
      when "diagnose"
        failure_modes = chapter.dig("gate_requirements", "critical_failure_modes")
        declared_modes = failure_modes.is_a?(Array) ? failure_modes.select { |mode| mode.is_a?(String) && !mode.empty? } : []
        strong_failure = contains_any?(text, FAILURE_TOKENS) || declared_modes.any? { |mode| concrete_failure_mode?(mode) && text.include?(mode) }
        if text.match?(/\A面对注入的.+故障[，,]指出失败阶段/) && !strong_failure
          return "diagnose outcome repeats the generic injected-failure template without a concrete failure mode"
        end
        enumerates_failures = text.include?("、") && text.match?(/(?:注入|制造|新增|从.+中|定位|重放|攻击)/)
        concrete = strong_failure || contains_any?(text, FAILURE_SIGNAL_TOKENS) || enumerates_failures
        return "diagnose outcome must name at least one concrete failure mode" unless concrete
      end
      nil
    end

    def acceptance_issue(text)
      value = text.to_s
      if value.match?(/的成功、边界与故障场景均保存/)
        return "acceptance repeats the generic success/boundary/failure evidence template"
      end
      return "acceptance must contain a decidable oracle" unless contains_any?(value, ORACLE_TOKENS)

      nil
    end

    def contains_any?(text, tokens)
      tokens.any? { |token| text.include?(token) }
    end

    def concrete_failure_mode?(text)
      contains_any?(text.to_s, FAILURE_TOKENS)
    end
  end
end
