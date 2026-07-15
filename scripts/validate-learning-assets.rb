#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only umbrella validator for the learning-asset sprint.
# Semantic mastery, external page freshness, and runnable future project code
# still require separate human/runtime verification.

require "csv"
require "json"
require "open3"
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).parent.expand_path
SKILL = Pathname.new(ENV.fetch("FACTORYCARE_COACH_SKILL", File.expand_path("~/.codex/skills/factorycare-learning-coach")))
SKILL_CREATOR = Pathname.new(File.expand_path("~/.codex/skills/.system/skill-creator"))

errors = []
warnings = []
checks = 0
command_results = []

check = lambda do |condition, message|
  checks += 1
  errors << message unless condition
end

required_root_files = %w[
  README.md SPRINT_SCOPE.md LEARNING_PLAN.md TECH_STACK.md PROJECT_SPEC.md
  ASSESSMENTS.md AI_WORKFLOW.md JOB_SEARCH.md CONCEPT_MAP.md PROGRESS.md
  learning-kits/README.md job-market/README.md factorycare-design/README.md
].freeze

required_root_files.each do |relative|
  check.call(ROOT.join(relative).file?, "missing required entry: #{relative}")
end

# The authoritative roadmap must contain one correctly numbered plan for Week 00—48.
(0..48).each do |number|
  week = format("%02d", number)
  path = ROOT.join("weeks", "week-#{week}.md")
  check.call(path.file? && path.size.positive?, "missing or empty weekly plan: weeks/week-#{week}.md")
  next unless path.file?

  first_line = path.each_line(encoding: "UTF-8").first.to_s.strip
  check.call(first_line.match?(/^# 第 0*#{number} 周：/),
             "weekly plan heading does not match Week #{week}: #{first_line.inspect}")
end

# Every learning week must remain a teachable loop, not a technology-name checklist.
# Heading styles differ between the rewritten foundation weeks and retained project weeks,
# so the checks intentionally accept both numbered and unnumbered variants.
weekly_sections = {
  "learning goals" => /^##(?:\s+\d+\.)?\s*(?:本周)?(?:学习)?目标/m,
  "tasks" => /^##(?:\s+\d+\.)?\s*(?:课次与时间|时间与任务|任务分配|任务)/m,
  "acceptance" => /^##(?:\s+\d+\.)?\s*(?:交付物与验收|验收|验收标准)/m,
  "non-goals" => /^##(?:\s+\d+\.)?\s*(?:本周)?(?:明确不做|非目标)/m
}.freeze

(1..48).each do |number|
  week = format("%02d", number)
  path = ROOT.join("weeks", "week-#{week}.md")
  next unless path.file?

  source = path.read(encoding: "UTF-8")
  weekly_sections.each do |label, pattern|
    check.call(source.match?(pattern), "Week #{week} lacks a recognizable #{label} section")
  end
  check.call(source.match?(/无\s*AI/i), "Week #{week} lacks an explicit no-AI practice or assessment")
  check.call(source.include?("FactoryCare"), "Week #{week} is not connected to the FactoryCare project")
end

# Language foundations are protected by semantic anchors. These checks do not prove
# teaching quality, but they stop future schedule edits from silently skipping the basics.
foundation_anchors = {
  1 => ["main", "System.out", "Scanner", "基本类型", "方法", "JUnit"],
  2 => ["String", "null", "数组", "if", "switch", "for", "while"],
  3 => ["类", "对象", "构造器", "封装", "static", "final"],
  4 => ["继承", "接口", "抽象类", "多态", "组合", "record", "enum"],
  5 => ["集合", "泛型", "List", "Set", "Map", "equals", "hashCode"],
  6 => ["异常", "try-with-resources", "Path", "文件", "Instant", "JSON"],
  7 => ["Lambda", "Stream", "Optional"],
  8 => ["线程", "ExecutorService", "CompletableFuture", "虚拟线程", "JVM"],
  12 => ["SELECT", "WHERE", "NULL", "JOIN", "GROUP BY", "HAVING", "CTE", "窗口函数", "INSERT", "UPDATE", "DELETE", "SQL 注入"],
  22 => ["HTML", "语义", "表单", "可访问性", "CSS", "盒模型", "Flex", "Grid", "响应式"],
  23 => ["JavaScript", "类型", "作用域", "闭包", "函数", "this", "对象", "原型", "模块"],
  24 => ["DOM", "事件", "事件循环", "Promise", "Fetch", "AbortController", "浏览器安全"],
  25 => ["TypeScript", "联合", "收窄", "泛型", "unknown", "null", "tsconfig", "运行时"],
  26 => ["Vue 3", "SFC", "ref", "reactive", "computed", "watch", "组件", "生命周期", "Composable"],
  27 => ["Vite", "Router", "Pinia", "服务端状态", "Element Plus"],
  28 => ["Nuxt 4", "CSR", "SSR", "SSG", "Hydration", "数据获取"],
  29 => ["Vitest", "Vue Testing Library", "Playwright", "SSE", "错误恢复"],
  30 => ["uni-app", "Vue 3", "条件编译", "网络", "认证", "扫码"],
  31 => ["uni-app", "真机", "上传", "权限", "缓存", "推送", "支付", "发布"],
  32 => ["Dart", "类型", "空安全", "控制流", "函数", "List", "Map", "测试"],
  33 => ["Dart", "类", "泛型", "异常", "Future", "Stream", "isolate", "测试"],
  34 => ["Flutter", "Widget", "Element", "RenderObject", "生命周期", "布局", "BuildContext", "Key", "导航", "表单", "状态"],
  35 => ["Flutter", "API", "认证", "离线", "幂等", "冲突", "扫码", "拍照", "构建"],
  36 => ["Python", "类型", "字符串", "I/O", "list", "tuple", "dict", "set", "if", "for", "while", "函数", "模块"],
  37 => ["Python", "class", "dataclass", "异常", "文件", "iterator", "generator", "typing", "pytest", "uv"],
  38 => ["Python", "async", "FastAPI", "Pydantic", "配置", "日志", "服务测试"],
  39 => ["机器学习", "深度学习", "PyTorch", "数据泄漏", "训练", "推理", "评估"],
  40 => ["模型API", "结构化输出", "流式", "工具调用", "prompt", "超时"],
  41 => ["RAG", "解析", "切块", "embedding", "全文检索", "向量检索", "引用", "ACL"],
  42 => ["评估", "重排", "安全", "成本", "可观测", "提示注入"],
  43 => ["Agent", "工作流", "状态", "工具", "LangGraph", "MCP", "HITL"]
}.freeze

foundation_anchors.each do |number, anchors|
  week = format("%02d", number)
  path = ROOT.join("weeks", "week-#{week}.md")
  next unless path.file?

  source = path.read(encoding: "UTF-8")
  anchors.each do |anchor|
    check.call(source.downcase.include?(anchor.downcase), "Week #{week} foundation anchor missing: #{anchor}")
  end
end

weeks_readme = ROOT.join("weeks", "README.md")
if weeks_readme.file?
  source = weeks_readme.read(encoding: "UTF-8")
  check.call(source.include?("恢复求职") && source.match?(/(?:不阻塞|不计入.*验收|不是.*前置)/),
             "weeks/README.md lacks the paused-job-search non-blocking rule")
end

# Every teaching week has exactly the six intentional files and non-empty content.
teaching_files = %w[README.md concepts.md labs.md assessment.md answers.md interview.md].freeze
(0..8).each do |number|
  week = format("%02d", number)
  directory = ROOT.join("learning-kits", "week-#{week}")
  actual = directory.glob("*.md").map(&:basename).map(&:to_s).sort
  check.call(actual == teaching_files.sort, "Week #{week} teaching files differ: #{actual.inspect}")
  teaching_files.each do |file_name|
    path = directory.join(file_name)
    check.call(path.file? && path.size.positive?, "missing or empty teaching file: #{path.relative_path_from(ROOT)}")
  end

  unless number.zero?
    combined = [directory.join("labs.md"), directory.join("answers.md")]
               .select(&:file?).map { |path| path.read(encoding: "UTF-8") }.join("\n")
    check.call(combined.match?(/O\s*\(/), "Week #{week} lacks an explicit algorithm complexity statement")
  end

  assessment = directory.join("assessment.md")
  if assessment.file?
    source = assessment.read(encoding: "UTF-8")
    check.call(!source.match?(/^##\s*(参考)?答案/m), "Week #{week} assessment contains an answer section")
    %w[概念解释 最小实验 项目增量 测试与排错].each do |category|
      check.call(source.include?(category), "Week #{week} assessment lacks score category #{category}")
    end
    check.call(source.match?(/无\s*AI\s*任务/), "Week #{week} assessment lacks score category 无 AI 任务")
    check.call(source.include?("复盘与求职"), "Week #{week} assessment lacks score category 复盘与求职")
  end

  interview = directory.join("interview.md")
  answers = directory.join("answers.md")
  if interview.file? && answers.file?
    interview_source = interview.read(encoding: "UTF-8")
    answer_source = answers.read(encoding: "UTF-8")
    answer_headings = interview_source.each_line.select do |line|
      line.match?(/^(?:##|###|####)\s+.*(?:参考回答|答案锚点|回答锚点)/)
    end
    check.call(answer_headings.empty?, "Week #{week} interview still contains answer headings")
    check.call(answer_source.match?(/^##\s+面试校准/m), "Week #{week} answers lacks interview calibration")
  end
end

# Parse all machine-readable assets and check CSV row widths.
ROOT.glob("**/*.json").sort.each do |path|
  begin
    JSON.parse(path.read(encoding: "UTF-8"))
    checks += 1
  rescue JSON::ParserError => e
    errors << "invalid JSON #{path.relative_path_from(ROOT)}: #{e.message}"
  end
end

ROOT.glob("**/*.yaml").sort.each do |path|
  begin
    YAML.safe_load(path.read(encoding: "UTF-8"), aliases: false)
    checks += 1
  rescue Psych::Exception => e
    errors << "invalid YAML #{path.relative_path_from(ROOT)}: #{e.message.lines.first.strip}"
  end
end

ROOT.glob("**/*.csv").sort.each do |path|
  begin
    rows = CSV.read(path, encoding: "bom|utf-8")
    check.call(!rows.empty?, "empty CSV: #{path.relative_path_from(ROOT)}")
    next if rows.empty?

    width = rows.first.length
    invalid_rows = []
    rows.each_with_index do |row, index|
      invalid_rows << index + 1 unless row.length == width
    end
    check.call(invalid_rows.empty?, "CSV width mismatch #{path.relative_path_from(ROOT)} rows #{invalid_rows.join(', ')}")
  rescue CSV::MalformedCSVError, ArgumentError => e
    errors << "invalid CSV #{path.relative_path_from(ROOT)}: #{e.message}"
  end
end

# Check local Markdown links and fence balance across the workspace.
markdown_files = ROOT.glob("**/*.md").sort
markdown_files.each do |path|
  source = path.read(encoding: "UTF-8")
  backtick_fences = source.each_line.count { |line| line.match?(/^\s*```/) }
  tilde_fences = source.each_line.count { |line| line.match?(/^\s*~~~/) }
  check.call(backtick_fences.even?, "unclosed backtick fence: #{path.relative_path_from(ROOT)}")
  check.call(tilde_fences.even?, "unclosed tilde fence: #{path.relative_path_from(ROOT)}")

  source.scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |raw_target|
    target = raw_target.strip
    next if target.empty? || target.start_with?("#", "http://", "https://", "mailto:", "data:")

    # Support angle-bracket paths. Local links in this workspace do not use a title suffix.
    target = target[1...-1] if target.start_with?("<") && target.end_with?(">")
    file_part = target.split("#", 2).first
    linked = Pathname.new(file_part)
    linked = path.dirname.join(linked).cleanpath unless linked.absolute?
    check.call(linked.exist?, "broken link #{path.relative_path_from(ROOT)} -> #{raw_target}")
  end
end

run = lambda do |label, *command|
  stdout, stderr, status = Open3.capture3(*command, chdir: ROOT.to_s)
  command_results << {
    label: label,
    ok: status.success?,
    output: [stdout, stderr].reject(&:empty?).join("\n").strip
  }
  errors << "#{label} failed (#{command.join(' ')})" unless status.success?
end

run.call("FactoryCare design", "ruby", "factorycare-design/scripts/validate-design.rb")
run.call("Nanchang job snapshot", "python3", "job-market/scripts/validate.py")

quick_validate = SKILL_CREATOR.join("scripts/quick_validate.py")
check.call(SKILL.join("SKILL.md").file?, "missing learning coach Skill: #{SKILL}")
check.call(quick_validate.file?, "missing Skill Creator validator: #{quick_validate}")
if SKILL.join("SKILL.md").file? && quick_validate.file?
  run.call("Learning coach Skill", "python3", quick_validate.to_s, SKILL.to_s)
  run.call("Progress detector", "ruby", SKILL.join("scripts/check_progress.rb").to_s,
           "--workspace", ROOT.to_s, "--json")
end

puts "Learning asset sprint validation"
puts "root: #{ROOT}"
puts "markdown_files: #{markdown_files.length}"
puts "checks: #{checks}"

command_results.each do |result|
  puts "\n[#{result[:ok] ? 'PASS' : 'FAIL'}] #{result[:label]}"
  puts result[:output] unless result[:output].empty?
end

unless warnings.empty?
  puts "\nWarnings:"
  warnings.each { |message| puts "  - #{message}" }
end

if errors.empty?
  puts "\nVALIDATION_OK"
  exit 0
end

puts "\nVALIDATION_FAILED: #{errors.length} error(s)"
errors.each { |message| puts "  - #{message}" }
exit 1
