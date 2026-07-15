#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "optparse"
require "pathname"
require "set"
require "tmpdir"
require "yaml"

# Builds a copyright-conservative provenance and migration inventory for two
# audited note repositories. Public artifacts contain hashes and unreviewed
# canonical chapter candidates; verbatim paths/headings are optional, local,
# and written only below the gitignored sources/private/ directory.
module SourceInventory
  SCHEMA_VERSION = 2

  CANONICAL_REPOSITORIES = {
    "note" => {
      "url" => "https://github.com/YouRen1320/Note.git",
      "commit" => "72b27e3bad732fa86d5fd9d9c990c6d5ecaf9f96",
      "default_path" => "/tmp/factorycare-note-audit.SOGSxV/Note"
    },
    "java-note" => {
      "url" => "https://github.com/YouRen1320/Java-Note.git",
      "commit" => "3c4928bf78b24d6550538ea388240fe3b4ce407e",
      "default_path" => "/tmp/factorycare-note-audit.SOGSxV/Java-Note"
    }
  }.freeze

  EXPECTED_COMMITS = CANONICAL_REPOSITORIES.each_with_object({}) do |(key, value), memo|
    memo[key] = value.fetch("commit")
  end.freeze
  DEFAULT_REPOSITORIES = CANONICAL_REPOSITORIES.each_with_object({}) do |(key, value), memo|
    memo[key] = value.fetch("default_path")
  end.freeze

  PUBLIC_FILES = %w[
    README.md ADVERSARIAL-REVIEW.md catalog.yml files.csv mappings.csv migration-policy.md
  ].freeze
  PRIVATE_FILES = %w[README.md files.raw.jsonl sections.raw.jsonl].freeze

  FILE_COLUMNS = %w[
    file_id repository commit path_sha256 content_sha256 type detected_kind size_bytes
    domain license_state copyright_risk default_action target_kind target_id reason
  ].freeze
  MAPPING_COLUMNS = %w[
    section_id file_id repository commit locator_sha256 heading_sha256 level
    concept_candidates target_kind target_id chapter_ids disposition decision_reason
    mapping_method mapping_confidence review_status official_source_required
    official_source_state verification_required verification_state copyright_state
  ].freeze

  ASSET_EXTENSIONS = %w[
    .png .jpg .jpeg .gif .bmp .webp .awebp .svg .ico
    .eot .otf .ttf .woff .woff2 .thmx
  ].freeze
  ARCHIVE_EXTENSIONS = %w[.jar .zip .rar .7z .ziw .chm .chw].freeze
  DOCUMENT_EXTENSIONS = %w[.pdf .doc .docx .xls .xlsx .ppt .pptx].freeze
  COMPILED_EXTENSIONS = %w[.class .kotlin_module .pyc .o .so .dylib .dll .exe].freeze
  METADATA_NAMES = %w[.DS_Store desktop.ini thumbs.db].freeze
  BUILD_DIRECTORY_NAMES = %w[target build out .gradle .dart_tool .nuxt .output].freeze

  # Domain policy contains semantic volume numbers, never duplicated book slugs
  # or chapter IDs. Slugs and IDs are resolved from curriculum/catalog.yml.
  DOMAIN_DESTINATIONS = {
    "source-governance" => { "kind" => "source-only", "id" => "source-governance" },
    "generated-metadata" => { "kind" => "source-only", "id" => "generated-metadata" },
    "developer-tooling" => { "kind" => "volume", "volume" => "00" },
    "html-css" => { "kind" => "volume", "volume" => "07" },
    "javascript" => { "kind" => "volume", "volume" => "08" },
    "typescript" => { "kind" => "volume", "volume" => "08" },
    "vue" => { "kind" => "volume", "volume" => "09" },
    "vue-project" => { "kind" => "volume", "volume" => "09" },
    "wechat-mini-program" => { "kind" => "volume", "volume" => "10" },
    "uni-app" => { "kind" => "volume", "volume" => "10" },
    "harmonyos" => { "kind" => "future-extension", "id" => "harmonyos" },
    "node-tooling" => { "kind" => "volume", "volume" => "08" },
    "node-backend" => { "kind" => "appendix", "id" => "node-backends" },
    "flutter" => { "kind" => "volume", "volume" => "11" },
    "data-visualization" => { "kind" => "appendix", "id" => "data-visualization" },
    "nuxt" => { "kind" => "volume", "volume" => "09" },
    "java-foundations" => { "kind" => "volume", "volume" => "01" },
    "java-object-model" => { "kind" => "volume", "volume" => "02" },
    "java-engineering-runtime" => { "kind" => "volume", "volume" => "03" },
    "sql-database" => { "kind" => "volume", "volume" => "04" },
    "legacy-java-web" => { "kind" => "volume", "volume" => "05" },
    "maven" => { "kind" => "volume", "volume" => "03" },
    "mybatis" => { "kind" => "volume", "volume" => "05" },
    "spring" => { "kind" => "volume", "volume" => "05" },
    "linux" => { "kind" => "volume", "volume" => "15" },
    "redis" => { "kind" => "volume", "volume" => "06" },
    "security-rbac" => { "kind" => "volume", "volume" => "06" },
    "microservices" => { "kind" => "volume", "volume" => "06" },
    "payment-project" => { "kind" => "volume", "volume" => "06" },
    "interview-material" => { "kind" => "appendix", "id" => "interview-evidence" },
    "enterprise-project" => { "kind" => "volume", "volume" => "15" },
    "unclassified" => { "kind" => "manual-triage", "id" => "unclassified" }
  }.freeze

  ConceptRule = Struct.new(:domains, :pattern, :concept, :selectors, keyword_init: true)

  JAVA_FOUNDATION = %w[java-foundations].freeze
  JAVA_OBJECT = %w[java-object-model].freeze
  JAVA_ENGINEERING = %w[java-engineering-runtime maven].freeze
  DATA = %w[sql-database mybatis redis].freeze
  SPRING = %w[spring legacy-java-web mybatis].freeze
  SECURITY = %w[security-rbac microservices payment-project].freeze
  WEB = %w[html-css].freeze
  JS = %w[javascript node-tooling node-backend].freeze
  TS = %w[typescript].freeze
  VUE = %w[vue vue-project nuxt uni-app wechat-mini-program].freeze
  MINI = %w[wechat-mini-program uni-app].freeze
  FLUTTER = %w[flutter].freeze
  PRODUCTION = %w[linux enterprise-project microservices].freeze
  TOOLING = %w[developer-tooling].freeze

  # Rules are domain-scoped. Selectors search canonical chapter metadata and do
  # not duplicate chapter IDs, so catalog changes fail or alter suggestions
  # visibly instead of silently retaining stale identifiers.
  CONCEPT_RULES = [
    ConceptRule.new(domains: TOOLING, pattern: /IDEA|编辑器|调试|断点|调用栈/i, concept: "tooling.editor-debugger", selectors: %w[editor-debugger 编辑器 调试器]),

    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /变量|作用域|生命周期/i, concept: "java.variables-scope", selectors: %w[variables-scope 变量 作用域]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /基本类型|数据类型|字符|布尔/i, concept: "java.primitive-types", selectors: %w[primitive-types 基本类型]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /运算符|类型转换|溢出/i, concept: "java.operators-conversion", selectors: %w[operators-conversion 运算符]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /条件|分支|\bif\b|\bswitch\b/i, concept: "java.conditionals", selectors: %w[conditionals-switch 条件 switch]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /循环|\bfor\b|\bwhile\b|\bbreak\b|\bcontinue\b/i, concept: "java.loops", selectors: %w[loops-control 循环]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /方法|参数|返回值|重载|递归/i, concept: "java.methods", selectors: %w[methods 方法]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /数组/i, concept: "java.arrays", selectors: %w[arrays-debug-test 数组]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /输入|输出|Scanner|命令行参数/i, concept: "java.console-io", selectors: %w[console-io 输入输出]),
    ConceptRule.new(domains: JAVA_FOUNDATION, pattern: /JDK|JVM|编译|运行|Java平台/i, concept: "java.platform", selectors: %w[java-platform JDK JVM]),

    ConceptRule.new(domains: JAVA_OBJECT, pattern: /类和对象|类与对象|面向对象|字段|实例方法/i, concept: "java.classes-objects", selectors: %w[classes-fields-methods 类 对象]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /构造器|封装|访问权限|访问修饰/i, concept: "java.encapsulation", selectors: %w[constructors-encapsulation 封装]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /\bstatic\b|\bfinal\b|不可变/i, concept: "java.static-final", selectors: %w[static-final-immutability static final]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /继承|\bsuper\b|组合/i, concept: "java.inheritance-composition", selectors: %w[inheritance-composition 继承]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /多态|接口|抽象类|动态分派/i, concept: "java.polymorphism-interfaces", selectors: %w[polymorphism-interfaces 多态 接口]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /异常|Exception|资源关闭/i, concept: "java.exceptions", selectors: %w[exceptions-resources 异常]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /String|正则|时间 API|BigDecimal/i, concept: "java.value-types", selectors: %w[core-value-types String BigDecimal]),
    ConceptRule.new(domains: JAVA_OBJECT, pattern: /enum|record|sealed|枚举/i, concept: "java.modern-types", selectors: %w[enum-record-sealed enum record]),

    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /集合|Collection|\bList\b|\bSet\b|\bMap\b|Deque/i, concept: "java.collections", selectors: %w[collections 集合 List Map]),
    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /泛型|Generic|Comparator|通配符/i, concept: "java.generics", selectors: %w[generics-comparator 泛型]),
    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /Lambda|函数式接口|方法引用/i, concept: "java.lambdas", selectors: %w[lambdas-functions Lambda]),
    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /(?:\bStream\b|Collector|Optional|流式)/i, concept: "java.streams", selectors: %w[streams-optional Stream Optional]),
    ConceptRule.new(domains: JAVA_ENGINEERING + JAVA_OBJECT, pattern: /IO流|输入流|输出流|NIO|File类|InputStream|OutputStream/i, concept: "java.io-nio", selectors: %w[io-nio-json IO NIO]),
    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /多线程|并发|线程|Java内存模型|JMM|锁|synchronized/i, concept: "java.threads-jmm", selectors: %w[threads-jmm 线程 同步]),
    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /线程池|Executor|Future|虚拟线程|异步/i, concept: "java.executors-async", selectors: %w[executors-virtual-threads Future 异步]),
    ConceptRule.new(domains: JAVA_ENGINEERING, pattern: /反射|Reflection|注解|Annotation|类加载|动态代理/i, concept: "java.reflection-proxy", selectors: %w[annotations-reflection-proxy 反射 注解]),
    ConceptRule.new(domains: JAVA_ENGINEERING + %w[maven], pattern: /Maven|JUnit|单元测试|Mock|JVM诊断/i, concept: "java.maven-testing", selectors: %w[maven-testing-jvm Maven JUnit]),

    ConceptRule.new(domains: DATA, pattern: /SELECT|查询|过滤|排序|分页/i, concept: "data.sql-query", selectors: %w[sql-query-basics SELECT]),
    ConceptRule.new(domains: DATA, pattern: /分组|GROUP BY|HAVING|聚合/i, concept: "data.sql-aggregation", selectors: %w[aggregate-group-having 聚合]),
    ConceptRule.new(domains: DATA, pattern: /JOIN|连接查询|子查询|CTE|窗口函数/i, concept: "data.sql-joins", selectors: %w[joins-subquery-cte JOIN]),
    ConceptRule.new(domains: DATA, pattern: /索引|B\+?Tree|EXPLAIN|查询计划/i, concept: "data.indexes", selectors: %w[indexes-explain 索引]),
    ConceptRule.new(domains: DATA, pattern: /事务|ACID|隔离级别|死锁|锁/i, concept: "data.transactions", selectors: %w[transactions-locks 事务]),
    ConceptRule.new(domains: DATA, pattern: /JDBC|连接池|MyBatis|Flyway/i, concept: "data.persistence", selectors: %w[migration-jdbc-mybatis JDBC MyBatis]),
    ConceptRule.new(domains: %w[redis] + SECURITY, pattern: /Redis|缓存|TTL|限流/i, concept: "data.redis-cache", selectors: %w[redis-cache-rate-limit Redis]),

    ConceptRule.new(domains: SPRING, pattern: /Servlet|Jakarta|请求生命周期/i, concept: "spring.web-lifecycle", selectors: %w[web-jakarta-lifecycle Servlet]),
    ConceptRule.new(domains: SPRING, pattern: /Spring|IoC|IOC|依赖注入|\bDI\b|Bean|组件/i, concept: "spring.ioc-di", selectors: %w[ioc-di-beans IoC Bean]),
    ConceptRule.new(domains: SPRING, pattern: /Spring Boot|SpringBoot|Starter|自动配置/i, concept: "spring.boot", selectors: %w[boot-autoconfiguration Spring Boot]),
    ConceptRule.new(domains: SPRING, pattern: /Spring MVC|SpringMVC|Controller|请求映射/i, concept: "spring.mvc", selectors: %w[mvc-controllers Controller]),
    ConceptRule.new(domains: SPRING, pattern: /AOP|动态代理|事务边界|Service/i, concept: "spring.aop-transactions", selectors: %w[services-transactions-aop AOP]),
    ConceptRule.new(domains: SPRING, pattern: /MyBatis|动态 SQL|数据访问/i, concept: "spring.mybatis", selectors: %w[mybatis-integration MyBatis]),
    ConceptRule.new(domains: SPRING, pattern: /测试|Testcontainers|OpenAPI|Actuator/i, concept: "spring.testing-operations", selectors: %w[testing-openapi-actuator 测试]),

    ConceptRule.new(domains: SECURITY, pattern: /JWT|OAuth|OIDC/i, concept: "security.jwt-oauth", selectors: %w[jwt-oauth-oidc JWT OAuth]),
    ConceptRule.new(domains: SECURITY, pattern: /认证|Cookie|Session|密码/i, concept: "security.authentication", selectors: %w[auth-session-password 认证]),
    ConceptRule.new(domains: SECURITY, pattern: /CSRF|XSS|SSRF|CORS|注入/i, concept: "security.web-threats", selectors: %w[web-security-threats CSRF XSS]),
    ConceptRule.new(domains: SECURITY, pattern: /RBAC|ABAC|权限|多租户|审计/i, concept: "security.authorization", selectors: %w[rbac-multitenancy-audit RBAC]),
    ConceptRule.new(domains: SECURITY, pattern: /幂等|状态机|SLA|并发控制/i, concept: "architecture.state-idempotency", selectors: %w[state-sla-idempotency 幂等]),
    ConceptRule.new(domains: SECURITY, pattern: /消息|MQ|RabbitMQ|Outbox|事件/i, concept: "architecture.events", selectors: %w[events-outbox-messaging Outbox]),
    ConceptRule.new(domains: SECURITY, pattern: /微服务|模块化|Nacos|服务发现|可观测/i, concept: "architecture.modularity", selectors: %w[modular-monolith-observability 微服务]),

    ConceptRule.new(domains: WEB, pattern: /HTML|标签|语义|文档结构/i, concept: "web.html-semantics", selectors: %w[semantic-html HTML]),
    ConceptRule.new(domains: WEB, pattern: /表单|校验|图片|音视频/i, concept: "web.forms-media", selectors: %w[forms-media-validation 表单]),
    ConceptRule.new(domains: WEB, pattern: /CSS|样式|层叠|选择器|优先级/i, concept: "web.css-cascade", selectors: %w[css-cascade CSS]),
    ConceptRule.new(domains: WEB, pattern: /Flex|弹性盒|Grid|网格布局/i, concept: "web.layout", selectors: %w[flex-grid Flexbox Grid]),
    ConceptRule.new(domains: WEB, pattern: /响应式|媒体查询|排版/i, concept: "web.responsive", selectors: %w[responsive-typography 响应式]),

    ConceptRule.new(domains: JS, pattern: /变量|数据类型|类型转换|相等|空值/i, concept: "js.values-types", selectors: %w[values-types-equality 值 类型]),
    ConceptRule.new(domains: JS, pattern: /作用域|闭包|函数|控制流/i, concept: "js.scope-functions", selectors: %w[scope-functions-closures 作用域 闭包]),
    ConceptRule.new(domains: JS, pattern: /数组|对象|\bMap\b|\bSet\b/i, concept: "js.collections", selectors: %w[arrays-objects-collections 数组]),
    ConceptRule.new(domains: JS, pattern: /\bthis\b|原型|prototype|\bclass\b|模块/i, concept: "js.this-prototype", selectors: %w[this-prototype-class-module this 原型]),
    ConceptRule.new(domains: JS, pattern: /DOM|事件|表单|storage|存储/i, concept: "js.dom-events", selectors: %w[dom-events-storage DOM]),
    ConceptRule.new(domains: JS, pattern: /事件循环|Event Loop|宏任务|微任务|Promise|async|await/i, concept: "js.event-loop-promises", selectors: %w[event-loop-promises Promise]),
    ConceptRule.new(domains: JS, pattern: /Fetch|Axios|Ajax|AbortController|请求|竞态/i, concept: "js.http-race", selectors: %w[fetch-abort-race Fetch]),
    ConceptRule.new(domains: TS, pattern: /TypeScript|tsconfig|strict|联合|收窄/i, concept: "ts.strict", selectors: %w[typescript-setup-strict tsconfig]),
    ConceptRule.new(domains: TS, pattern: /泛型|高级类型|类型体操|运行时校验/i, concept: "ts.advanced", selectors: %w[typescript-advanced-tooling 泛型]),

    ConceptRule.new(domains: VUE, pattern: /Vue|响应式|ref|reactive|computed/i, concept: "vue.reactivity", selectors: %w[reactivity 响应式]),
    ConceptRule.new(domains: VUE, pattern: /组件|props|emit|插槽|slot|v-model/i, concept: "vue.components", selectors: %w[components-contracts 组件]),
    ConceptRule.new(domains: VUE, pattern: /生命周期|mounted|unmounted|watch|effect|副作用/i, concept: "vue.lifecycle", selectors: %w[watch-lifecycle-cleanup 生命周期]),
    ConceptRule.new(domains: VUE, pattern: /Router|路由|导航/i, concept: "vue.router", selectors: %w[router-navigation-auth Router]),
    ConceptRule.new(domains: VUE, pattern: /Pinia|Vuex|状态管理|表单/i, concept: "vue.state", selectors: %w[pinia-server-state-forms Pinia]),
    ConceptRule.new(domains: %w[nuxt], pattern: /Nuxt|SSR|SSG|服务端渲染|Hydration|水合/i, concept: "nuxt.rendering", selectors: %w[nuxt-rendering-deployment Nuxt]),

    ConceptRule.new(domains: MINI, pattern: /小程序|生命周期|运行模型|配置/i, concept: "miniprogram.runtime", selectors: %w[miniprogram-runtime 小程序]),
    ConceptRule.new(domains: MINI, pattern: /uni-?app|页面|组件|路由/i, concept: "uniapp.pages", selectors: %w[uniapp-vue-pages uni-app]),
    ConceptRule.new(domains: MINI, pattern: /上传|扫码|定位|权限/i, concept: "uniapp.device", selectors: %w[upload-scan-location 扫码]),
    ConceptRule.new(domains: MINI, pattern: /分包|性能|缓存|离线/i, concept: "uniapp.performance", selectors: %w[packages-performance-offline 分包]),

    ConceptRule.new(domains: FLUTTER, pattern: /Dart|类型|空安全|pubspec/i, concept: "dart.language", selectors: %w[dart-cli-types Dart]),
    ConceptRule.new(domains: FLUTTER, pattern: /Future|Stream|Isolate|异步|取消/i, concept: "dart.async", selectors: %w[dart-async-errors Future Stream]),
    ConceptRule.new(domains: FLUTTER, pattern: /Flutter|Widget|Element|RenderObject/i, concept: "flutter.runtime", selectors: %w[flutter-runtime Widget]),
    ConceptRule.new(domains: FLUTTER, pattern: /状态|生命周期|BuildContext|mounted|Key/i, concept: "flutter.lifecycle", selectors: %w[state-lifecycle-mounted mounted]),
    ConceptRule.new(domains: FLUTTER, pattern: /导航|表单|网络|存储|设备 API/i, concept: "flutter.platform", selectors: %w[navigation-network-device 导航]),

    ConceptRule.new(domains: PRODUCTION, pattern: /Linux|CentOS|Ubuntu|用户|权限|进程|服务/i, concept: "production.linux", selectors: %w[linux-operations Linux]),
    ConceptRule.new(domains: PRODUCTION, pattern: /Docker|容器|镜像|Compose/i, concept: "production.containers", selectors: %w[docker-compose Docker]),
    ConceptRule.new(domains: PRODUCTION, pattern: /DNS|TLS|代理|端口|网络诊断/i, concept: "production.network", selectors: %w[network-diagnostics DNS TLS]),
    ConceptRule.new(domains: PRODUCTION, pattern: /部署|迁移|回滚|事故|灾难恢复/i, concept: "production.deployment", selectors: %w[deployment-rollback-incident 部署]),
    ConceptRule.new(domains: PRODUCTION, pattern: /日志|指标|链路|告警|可观测/i, concept: "production.observability", selectors: %w[logs-metrics-traces 日志])
  ].freeze

  Repository = Struct.new(:key, :path, :canonical_url, :commit, :license_state, keyword_init: true)

  class CatalogIndex
    attr_reader :catalog_id, :edition, :chapter_ids, :chapters

    def initialize(path)
      @path = Pathname(path).expand_path
      raise "curriculum catalog does not exist: #{@path}" unless @path.file?

      data = YAML.safe_load(@path.read(encoding: "UTF-8"), aliases: false)
      raise "curriculum catalog root must be a mapping" unless data.is_a?(Hash)

      @catalog_id = data.fetch("catalog_id")
      @edition = data.fetch("edition")
      @chapters = data.fetch("chapters")
      raise "curriculum catalog chapters must be a non-empty array" unless @chapters.is_a?(Array) && !@chapters.empty?

      @chapter_ids = @chapters.map { |chapter| chapter.fetch("id") }.to_set
      raise "curriculum catalog contains duplicate chapter IDs" unless @chapter_ids.length == @chapters.length

      @chapters_by_volume = @chapters.group_by { |chapter| chapter.fetch("volume") }
      @volume_slug_by_number = {}
      @chapters_by_volume.each do |volume, volume_chapters|
        slugs = volume_chapters.map { |chapter| volume_slug_from_path(chapter.fetch("path")) }.uniq
        raise "volume #{volume} has inconsistent book slugs: #{slugs.inspect}" unless slugs.length == 1
        @volume_slug_by_number[volume] = slugs.first
      end
      duplicate_slugs = @volume_slug_by_number.group_by { |_volume, slug| slug }
                                                .select { |_slug, entries| entries.length > 1 }.keys
      unless duplicate_slugs.empty?
        raise "curriculum catalog reuses book volume slugs: #{duplicate_slugs.sort.join(", ")}"
      end

      required_volumes = DOMAIN_DESTINATIONS.values.select { |item| item.fetch("kind") == "volume" }
                                           .map { |item| item.fetch("volume") }.uniq.sort
      missing = required_volumes.reject { |volume| @volume_slug_by_number.key?(volume) }
      raise "curriculum catalog is missing source target volumes: #{missing.join(", ")}" unless missing.empty?
    end

    def volume_slug(volume)
      @volume_slug_by_number.fetch(volume) { raise "unknown canonical volume #{volume}" }
    end

    def volume_slugs
      @volume_slug_by_number.values.to_set
    end

    def chapters_for_volume(volume)
      @chapters_by_volume.fetch(volume).sort_by { |chapter| chapter.fetch("order") }
    end

    def chapter_volume_slug(chapter_id)
      chapter = @chapters.find { |item| item.fetch("id") == chapter_id }
      raise "unknown canonical chapter #{chapter_id}" unless chapter

      volume_slug(chapter.fetch("volume"))
    end

    private

    def volume_slug_from_path(path)
      match = path.match(%r{\Abook/(volume-[a-z0-9-]+)/chapters/[^/]+\.md\z})
      raise "catalog chapter path is not canonical: #{path}" unless match

      match[1]
    end
  end

  module_function

  def normalize_path(path)
    path.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�").unicode_normalize(:nfc)
  end

  def stable_hash(*parts)
    Digest::SHA256.hexdigest(parts.join("\0"))
  end

  def file_id(repository, commit, path)
    "file-#{stable_hash(repository, commit, normalize_path(path))}"
  end

  def section_id(file_identifier, line, heading)
    "section-#{stable_hash(file_identifier, line.to_s, heading)}"
  end

  def git_commit(root)
    output, error, status = Open3.capture3("git", "-C", root.to_s, "rev-parse", "HEAD")
    raise "cannot read Git commit for #{root}: #{error.strip}" unless status.success?

    output.strip
  end

  def git_tracked_paths(root)
    output, error, status = Open3.capture3("git", "-C", root.to_s, "ls-files", "-z")
    raise "cannot list tracked files for #{root}: #{error.strip}" unless status.success?

    output.split("\0").reject(&:empty?).map { |path| normalize_path(path) }.sort
  end

  def ensure_clean_worktree!(root)
    output, error, status = Open3.capture3("git", "-C", root.to_s, "status", "--porcelain", "--untracked-files=all")
    raise "cannot inspect Git worktree for #{root}: #{error.strip}" unless status.success?
    return if output.empty?

    raise "source worktree must be clean for a reproducible inventory: #{root}"
  end

  def root_license_state(root)
    names = Pathname(root).children.select(&:file?).map { |entry| entry.basename.to_s }
    detected = names.select { |name| name.match?(/\A(?:licen[cs]e|copying|notice|copyright)(?:[._-].*)?\z/i) }.sort
    return "no-root-license-file-detected" if detected.empty?

    "root-license-file-detected"
  end

  def file_type(path)
    extension = File.extname(path).downcase
    extension.empty? ? "no-extension" : extension.delete_prefix(".")
  end

  def markdown?(path)
    File.extname(path).casecmp?(".md")
  end

  def domain_for(repository, relative_path)
    path = relative_path.unicode_normalize(:nfc)
    return "generated-metadata" if METADATA_NAMES.include?(File.basename(path))
    return note_domain(path) if repository == "note"

    java_note_domain(path)
  end

  def note_domain(path)
    case path
    when %r{\A01\.HTML\+CSS(?:/|\z)}i then "html-css"
    when %r{\A02\.JS(?:/|\z)}i then "javascript"
    when %r{\A03\.TS(?:/|\z)}i then "typescript"
    when %r{\A04\.Vue(?:/|\z)}i then "vue"
    when %r{\A05\.Vue项目(?:/|\z)}i then "vue-project"
    when %r{\A06\.微信小程序(?:/|\z)}i then "wechat-mini-program"
    when %r{\A07\.Uniapp(?:/|\z)}i then "uni-app"
    when %r{\A08\.鸿蒙开发(?:/|\z)}i then "harmonyos"
    when %r{\A09\.Node\.js(?:/|\z)}i
      path.match?(/Nest|Express/i) ? "node-backend" : "node-tooling"
    when %r{\A10\.Flutter(?:/|\z)}i then "flutter"
    when %r{\A11\.数字可视化(?:/|\z)}i then "data-visualization"
    when %r{\A12\.Nuxt(?:/|\z)}i then "nuxt"
    when %r{\AREADME\.md\z}i then "source-governance"
    else "unclassified"
    end
  end

  def java_note_domain(path)
    case path
    when %r{\A1\.java基础(?:/|\z)}i then java_foundation_domain(path)
    when %r{\A2\.My SQL数据库技术(?:/|\z)}i then "sql-database"
    when %r{\A3\.web开发与实战(?:/|\z)}i then "legacy-java-web"
    when %r{\A4\.web框架核心技术(?:/|\z)}i
      return "maven" if path.match?(/maven/i)
      return "mybatis" if path.match?(/mybatis/i)
      return "spring" if path.match?(/spring/i)
      return "linux" if path.match?(/linux/i)
      return "redis" if path.match?(/redis/i)

      "spring"
    when %r{\A5\.权限管理系统(?:/|\z)}i then "security-rbac"
    when %r{\A6\.微服务(?:/|\z)}i then "microservices"
    when %r{\A7\.项目二：融宝平台(?:/|\z)}i then "payment-project"
    when %r{\A8\.面试题(?:/|\z)}i, %r{\A赠送：面试题2023(?:/|\z)}i then "interview-material"
    when %r{\A赠送：企业接轨项目(?:/|\z)}i then "enterprise-project"
    when %r{\AREADME\.md\z}i then "source-governance"
    else "unclassified"
    end
  end

  def java_foundation_domain(path)
    return "developer-tooling" if path.match?(/IntelliJ|IDEA的安装|IDEA 常用快捷键/i)
    return "legacy-java-web" if path.match?(/Tomcat|Servlet|JSP/i)
    return "java-foundations" if path.match?(/第0[1-5]章|语言概述|变量|运算符|流程控制|关键字/i)
    return "java-object-model" if path.match?(/第0[6-9]章|第11章|面向对象|对象之间|异常|常用类|深拷贝|浅拷贝/i)

    "java-engineering-runtime"
  end

  def destination_for(domain, catalog_index)
    policy = DOMAIN_DESTINATIONS.fetch(domain, DOMAIN_DESTINATIONS.fetch("unclassified"))
    if policy.fetch("kind") == "volume"
      {
        "kind" => "volume",
        "id" => catalog_index.volume_slug(policy.fetch("volume")),
        "volume" => policy.fetch("volume")
      }
    else
      { "kind" => policy.fetch("kind"), "id" => policy.fetch("id") }
    end
  end

  def build_path?(path)
    components = Pathname(path).each_filename.to_a
    !(components & BUILD_DIRECTORY_NAMES).empty?
  end

  def detected_kind(path)
    extension = File.extname(path.to_s).downcase
    return "compiled/#{extension.delete_prefix(".")}" if COMPILED_EXTENSIONS.include?(extension)
    return "build-output" if build_path?(path.to_s)

    bytes = File.binread(path, 64) || "".b
    return "empty" if bytes.empty?
    return "document/pdf" if bytes.start_with?("%PDF-")
    return "image/png" if bytes.start_with?("\x89PNG\r\n\x1A\n".b)
    return "image/jpeg" if bytes.start_with?("\xFF\xD8\xFF".b)
    return "image/gif" if bytes.start_with?("GIF87a", "GIF89a")
    return "archive/zip" if bytes.start_with?("PK\x03\x04".b, "PK\x05\x06".b, "PK\x07\x08".b)
    return "binary/java-class" if bytes.start_with?("\xCA\xFE\xBA\xBE".b)
    return "binary/elf" if bytes.start_with?("\x7FELF".b)
    return "binary/unknown" if bytes.include?("\x00".b)

    "text-or-unknown"
  rescue EOFError
    "empty"
  end

  def file_policy(repository, path, domain, absolute_path: nil)
    extension = File.extname(path).downcase
    basename = File.basename(path)
    kind = absolute_path ? detected_kind(absolute_path) : "text-or-unknown"

    if METADATA_NAMES.include?(basename) || path.include?("/.obsidian/") || path.start_with?(".obsidian/")
      return ["low-metadata-no-publication-value", "exclude-generated-metadata",
              "Editor or operating-system metadata is excluded from teaching content.", kind]
    end

    if build_path?(path) || kind.start_with?("compiled/", "binary/")
      return ["high-generated-or-compiled-binary", "exclude-generated-build-output",
              "Generated, compiled, or unknown binary output is excluded from migration.", kind]
    end

    if kind == "empty"
      return ["low-empty-file-no-publication-value", "exclude-empty-file",
              "An empty file supplies no teaching content and is excluded from migration.", kind]
    end

    if DOCUMENT_EXTENSIONS.include?(extension) || kind == "document/pdf"
      return ["high-unverified-document-rights", "coverage-only-do-not-copy",
              "Document bytes are used only to confirm coverage and are never published.", kind]
    end

    if ASSET_EXTENSIONS.include?(extension) || ARCHIVE_EXTENSIONS.include?(extension) || kind.start_with?("image/", "archive/")
      return ["high-unverified-binary-rights", "exclude-binary-asset",
              "Binary asset rights and provenance are unverified; the asset is excluded.", kind]
    end

    if repository == "java-note"
      action = if domain == "interview-material"
                 "verify-and-rewrite"
               elsif %w[legacy-java-web microservices payment-project].include?(domain)
                 "historical-problem-extraction"
               else
                 "rewrite-from-concepts"
               end
      return ["high-third-party-training-material", action,
              "Unlicensed third-party material supplies coverage signals only; all prose and code require independent authorship.", kind]
    end

    action = case domain
             when "harmonyos" then "future-extension-only"
             when "node-backend", "data-visualization" then "appendix-concept-rewrite"
             else "rewrite-from-concepts"
             end
    ["medium-unverified-authorship", action,
     "Authorship and reuse rights are unverified; retain only sanitized coverage signals and independently rewrite.", kind]
  end

  def section_action(file_action, heading)
    return "verify-and-rewrite" if heading.match?(/面试|答案|口诀|结论/i)
    return "modernize-or-history" if heading.match?(/Vue\s*2|Vuex|JDK\s*(?:8|17)|javax\.|JSP|Servlet|Tomcat\s*8|CentOS\s*7|Redis\s*4/i)
    return "security-review-required" if heading.match?(/MD5|JWT|Token|密码|密钥|CSRF|XSS|注入|权限/i)

    file_action
  end

  def applicable_rules(domain, text)
    CONCEPT_RULES.select { |rule| rule.domains.include?(domain) && text.match?(rule.pattern) }
  end

  def concept_analysis(path, heading, domain)
    heading_rules = applicable_rules(domain, heading)
    return [heading_rules, "heading"] unless heading_rules.empty?

    path_rules = applicable_rules(domain, File.basename(path))
    return [path_rules, "path"] unless path_rules.empty?

    [[], "none"]
  end

  def concept_candidates(path, heading, domain)
    rules, = concept_analysis(path, heading, domain)
    concepts = rules.map(&:concept).uniq.sort
    concepts.empty? ? ["review-needed:#{domain}"] : concepts
  end

  def chapter_candidates(path, heading, domain, destination, catalog_index)
    return non_book_mapping(domain, destination) unless destination.fetch("kind") == "volume"

    chapters = catalog_index.chapters_for_volume(destination.fetch("volume"))
    rules, origin = concept_analysis(path, heading, domain)
    scores = chapters.each_with_object({}) { |chapter, memo| memo[chapter.fetch("id")] = 0 }

    rules.each do |rule|
      rule.selectors.each do |selector|
        needle = selector.downcase
        chapters.each do |chapter|
          haystack = "#{chapter.fetch("id")} #{chapter.fetch("title")} #{Array(chapter["outcomes"]).join(" ")}".downcase
          scores[chapter.fetch("id")] += 12 if haystack.include?(needle)
        end
      end
    end

    chapters.each do |chapter|
      title_terms(chapter.fetch("title")).each do |term|
        scores[chapter.fetch("id")] += 5 if heading.downcase.include?(term.downcase)
      end
    end

    maximum = scores.values.max || 0
    if maximum.zero?
      ids = chapters.map { |chapter| chapter.fetch("id") }
      confidence = "heuristic-low"
      reason = "No reliable chapter signal; all chapters in the canonical volume remain unreviewed candidates."
    else
      ids = scores.select { |_id, score| score == maximum }.keys.sort.first(3)
      confidence = origin == "heading" && maximum >= 12 ? "heuristic-high" : "heuristic-medium"
      reason = "Catalog-derived chapter candidate(s) selected by domain-scoped title and concept signals; not human-confirmed."
    end

    {
      "chapter_ids" => ids,
      "disposition" => "map-to-book",
      "decision_reason" => reason,
      "mapping_method" => "heuristic-catalog-v1",
      "mapping_confidence" => confidence,
      "review_status" => "unreviewed",
      "official_source_required" => true,
      "official_source_state" => "required-not-linked",
      "verification_required" => true,
      "verification_state" => "required-not-run"
    }
  end

  def non_book_mapping(domain, destination)
    kind = destination.fetch("kind")
    disposition = case kind
                  when "appendix" then "appendix-rewrite"
                  when "future-extension" then "future-extension"
                  when "source-only" then "exclude-source-metadata"
                  else "manual-triage"
                  end
    excluded = kind == "source-only"
    {
      "chapter_ids" => [],
      "disposition" => disposition,
      "decision_reason" => "Policy routes #{domain} outside the first-edition canonical book; this disposition remains unreviewed.",
      "mapping_method" => "policy-disposition-v1",
      "mapping_confidence" => "policy",
      "review_status" => "unreviewed",
      "official_source_required" => !excluded,
      "official_source_state" => excluded ? "not-applicable" : "required-not-linked",
      "verification_required" => !excluded,
      "verification_state" => excluded ? "not-applicable" : "required-not-run"
    }
  end

  def title_terms(title)
    title.split(/[、，,；;：:（）()\/]|(?:与|和|及)/).map(&:strip).select do |term|
      term.length >= 2 && term.length <= 24
    end
  end

  # Extract ATX and Setext headings without returning body text or headings from
  # fenced code. Verbatim results are confined to the private JSONL ledger.
  def extract_markdown_headings(path)
    text = File.binread(path).force_encoding(Encoding::UTF_8).scrub("�")
    lines = text.lines
    headings = []
    fence = nil
    previous_candidate = nil
    front_matter = lines.first&.match?(/\A---[ \t]*(?:\r?\n)?\z/)

    lines.each_with_index do |raw_line, index|
      line_number = index + 1
      line = raw_line.delete_suffix("\n").delete_suffix("\r")

      if front_matter
        front_matter = false if line_number > 1 && line.match?(/\A(?:---|\.\.\.)[ \t]*\z/)
        next
      end

      if fence
        marker_character = Regexp.escape(fence.fetch(0))
        close_pattern = /\A[ \t]{0,3}#{marker_character}{#{fence.fetch(1)},}[ \t]*\z/
        fence = nil if line.match?(close_pattern)
        previous_candidate = nil
        next
      end

      if (match = line.match(/\A[ \t]{0,3}(`{3,}|~{3,})/))
        marker = match[1]
        fence = [marker[0], marker.length]
        previous_candidate = nil
        next
      end

      if (match = line.match(/\A[ \t]{0,3}(\#{1,6})(?:[ \t]+(.*)|([^\x00-\x7F].*))\z/))
        heading = normalize_heading(match[2] || match[3])
        headings << { "heading" => heading, "level" => match[1].length, "line" => line_number } unless heading.empty?
        previous_candidate = nil
        next
      end

      if previous_candidate && line.match?(/\A[ \t]{0,3}(?:={3,}|-{3,})[ \t]*\z/)
        level = line.include?("=") ? 1 : 2
        headings << {
          "heading" => normalize_heading(previous_candidate.fetch(:text)),
          "level" => level,
          "line" => previous_candidate.fetch(:line)
        }
        previous_candidate = nil
        next
      end

      previous_candidate = if !setext_candidate?(line) || line.match?(/\A[ \t]{0,3}(?:[-*_][ \t]*){3,}\z/)
                             nil
                           else
                             { text: line.strip, line: line_number }
                           end
    end
    headings
  end

  def normalize_heading(heading)
    heading.gsub(/!\[[^\]]*\]\([^)]*\)/, "")
           .gsub(/\[([^\]]+)\]\([^)]*\)/, '\\1')
           .gsub(/\{#[^}]+\}\s*\z/, "")
           .sub(/[ \t]+\#+[ \t]*\z/, "")
           .gsub(/[ \t]+/, " ")
           .strip
  end

  def setext_candidate?(line)
    stripped = line.strip
    return false if stripped.empty? || stripped.length > 200
    return false if stripped.match?(/\A(?:!\[|\[!|\*\*|__|[>+*|`<]|-\s|\d+[.)]\s)/)
    return false if stripped.include?("\t") || stripped.match?(/\s{3,}/)

    true
  end

  def csv_safe_cell(value)
    text = value.to_s
    text.match?(/\A[\t\r\n ]*[=+\-@]/) ? "'#{text}" : text
  end

  class Builder
    attr_reader :repositories, :output_root, :catalog_index

    def initialize(repository_paths:, output_root:, catalog_path:, expected_commits: EXPECTED_COMMITS,
                   check: false, include_private: false, quiet: false)
      @repository_paths = repository_paths
      @output_root = Pathname(output_root).expand_path
      @catalog_index = CatalogIndex.new(catalog_path)
      @expected_commits = expected_commits
      @check = check
      @include_private = include_private
      @quiet = quiet
      @repositories = []
      @files = []
      @mappings = []
      @raw_files = []
      @raw_sections = []
    end

    def run
      load_repositories
      raise "source inventory output root may not be a symbolic link: #{output_root}" if output_root.symlink?
      ensure_private_paths_are_ignored!
      inventory_files
      validate_inventory!
      artifacts = render_public_artifacts
      private_artifacts = render_private_artifacts
      @check ? check_outputs!(artifacts, private_artifacts) : transactional_write(artifacts, private_artifacts)
      print_summary unless @quiet
      true
    end

    private

    def ensure_private_paths_are_ignored!
      return unless @include_private || output_root.join("private").directory?

      probe = output_root.parent
      probe = probe.parent until probe.exist? || probe.root?
      git_root_output, _git_root_error, git_root_status = Open3.capture3(
        "git", "-C", probe.to_s, "rev-parse", "--show-toplevel"
      )
      return unless git_root_status.success?

      git_root = Pathname(git_root_output.strip).expand_path
      sentinels = [
        output_root.join("private", ".source-inventory-safety-check"),
        output_root.parent.join(".#{output_root.basename}.stage-safety-check", "private", "ledger"),
        output_root.parent.join(".#{output_root.basename}.backup-safety-check", "private", "ledger")
      ]
      sentinels.each do |path|
        _output, _error, status = Open3.capture3(
          "git", "-C", git_root.to_s, "check-ignore", "--quiet", "--no-index", path.to_s
        )
        next if status.success?

        raise "private source-audit paths must be Git-ignored before raw data is generated or preserved: #{path}"
      end
    end

    def load_repositories
      @repositories = @repository_paths.keys.sort.map do |key|
        raise "unknown repository key #{key}" unless CANONICAL_REPOSITORIES.key?(key)
        root = Pathname(@repository_paths.fetch(key)).expand_path
        raise "repository directory does not exist: #{root}" unless root.directory?

        SourceInventory.ensure_clean_worktree!(root)
        commit = SourceInventory.git_commit(root)
        expected = @expected_commits[key]
        raise "#{key} commit mismatch: expected #{expected}, found #{commit}" if expected && commit != expected

        Repository.new(
          key: key,
          path: root,
          canonical_url: CANONICAL_REPOSITORIES.fetch(key).fetch("url"),
          commit: commit,
          license_state: SourceInventory.root_license_state(root)
        )
      end
    end

    def inventory_files
      @repositories.each do |repository|
        relative_paths(repository.path).each do |relative_path, actual_relative_path|
          # IDs and public hashes use the NFC-normalized path, while filesystem
          # reads use the path spelling that actually exists on disk. This
          # keeps output stable without assuming every filesystem normalizes
          # Unicode names in the same way.
          absolute_path = repository.path.join(actual_relative_path)
          domain = SourceInventory.domain_for(repository.key, relative_path)
          destination = SourceInventory.destination_for(domain, catalog_index)
          risk, action, reason, detected = SourceInventory.file_policy(
            repository.key, relative_path, domain, absolute_path: absolute_path
          )
          identifier = SourceInventory.file_id(repository.key, repository.commit, relative_path)
          path_hash = Digest::SHA256.hexdigest(relative_path)
          content_hash = Digest::SHA256.file(absolute_path).hexdigest

          @files << {
            "file_id" => identifier,
            "repository" => repository.key,
            "commit" => repository.commit,
            "path_sha256" => path_hash,
            "content_sha256" => content_hash,
            "type" => SourceInventory.file_type(relative_path),
            "detected_kind" => detected,
            "size_bytes" => absolute_path.size,
            "domain" => domain,
            "license_state" => repository.license_state,
            "copyright_risk" => risk,
            "default_action" => action,
            "target_kind" => destination.fetch("kind"),
            "target_id" => destination.fetch("id"),
            "reason" => reason
          }
          @raw_files << {
            "file_id" => identifier,
            "repository" => repository.key,
            "commit" => repository.commit,
            "path" => relative_path,
            "path_sha256" => path_hash,
            "content_sha256" => content_hash
          }

          next unless SourceInventory.markdown?(relative_path)

          SourceInventory.extract_markdown_headings(absolute_path).each do |heading|
            line = heading.fetch("line")
            raw_heading = heading.fetch("heading")
            section_identifier = SourceInventory.section_id(identifier, line, raw_heading)
            chapter_mapping = SourceInventory.chapter_candidates(
              relative_path, raw_heading, domain, destination, catalog_index
            )
            concepts = SourceInventory.concept_candidates(relative_path, raw_heading, domain)
            copyright_state = repository.key == "java-note" ?
              "unlicensed-third-party-coverage-only" : "unverified-authorship-coverage-only"

            @mappings << {
              "section_id" => section_identifier,
              "file_id" => identifier,
              "repository" => repository.key,
              "commit" => repository.commit,
              "locator_sha256" => SourceInventory.stable_hash(identifier, line.to_s),
              "heading_sha256" => Digest::SHA256.hexdigest(raw_heading),
              "level" => heading.fetch("level"),
              "concept_candidates" => concepts.join("|"),
              "target_kind" => destination.fetch("kind"),
              "target_id" => destination.fetch("id"),
              "chapter_ids" => chapter_mapping.fetch("chapter_ids").join("|"),
              "disposition" => chapter_mapping.fetch("disposition"),
              "decision_reason" => chapter_mapping.fetch("decision_reason"),
              "mapping_method" => chapter_mapping.fetch("mapping_method"),
              "mapping_confidence" => chapter_mapping.fetch("mapping_confidence"),
              "review_status" => chapter_mapping.fetch("review_status"),
              "official_source_required" => chapter_mapping.fetch("official_source_required"),
              "official_source_state" => chapter_mapping.fetch("official_source_state"),
              "verification_required" => chapter_mapping.fetch("verification_required"),
              "verification_state" => chapter_mapping.fetch("verification_state"),
              "copyright_state" => copyright_state
            }
            @raw_sections << {
              "section_id" => section_identifier,
              "file_id" => identifier,
              "repository" => repository.key,
              "commit" => repository.commit,
              "path" => relative_path,
              "heading" => raw_heading,
              "level" => heading.fetch("level"),
              "line" => line
            }
          end
        end
      end

      @files.sort_by! { |row| [row.fetch("repository"), row.fetch("file_id")] }
      @mappings.sort_by! { |row| [row.fetch("repository"), row.fetch("file_id"), row.fetch("section_id")] }
      @raw_files.sort_by! { |row| [row.fetch("repository"), row.fetch("path")] }
      @raw_sections.sort_by! { |row| [row.fetch("repository"), row.fetch("path"), row.fetch("line"), row.fetch("heading")] }
    end

    def relative_paths(root)
      actual_by_normalized_path = {}
      Find.find(root.to_s) do |entry|
        if File.symlink?(entry)
          relative = Pathname(entry).relative_path_from(root)
          raise "symbolic links are not allowed in source inventories: #{root.join(relative)}"
        end
        if File.directory?(entry)
          if File.basename(entry) == ".git"
            Find.prune
          else
            next
          end
        end
        next unless File.file?(entry)

        raw_relative = Pathname(entry).relative_path_from(root).to_s
        normalized = SourceInventory.normalize_path(raw_relative)
        raise "Unicode-normalized path collision in #{root}: #{normalized}" if actual_by_normalized_path.key?(normalized)
        actual_by_normalized_path[normalized] = raw_relative
      end
      inventory_paths = actual_by_normalized_path.keys.sort
      tracked_paths = SourceInventory.git_tracked_paths(root)
      unless inventory_paths == tracked_paths
        missing = tracked_paths - inventory_paths
        extra = inventory_paths - tracked_paths
        raise "source files differ from tracked Git files for #{root}; missing=#{missing.first(5).inspect} extra=#{extra.first(5).inspect}"
      end
      inventory_paths.map { |normalized| [normalized, actual_by_normalized_path.fetch(normalized)] }
    end

    def validate_inventory!
      duplicate_values(@files, "file_id").each { |id| raise "duplicate file ID: #{id}" }
      duplicate_values(@mappings, "section_id").each { |id| raise "duplicate section ID: #{id}" }
      raise "raw/public file counts diverge" unless @raw_files.length == @files.length
      raise "raw/public section counts diverge" unless @raw_sections.length == @mappings.length

      files_by_id = @files.each_with_object({}) { |row, memo| memo[row.fetch("file_id")] = row }
      @files.each do |row|
        validate_required_values(row, FILE_COLUMNS, row.fetch("file_id"))
        expected_destination = SourceInventory.destination_for(row.fetch("domain"), catalog_index)
        unless row.fetch("target_kind") == expected_destination.fetch("kind") &&
               row.fetch("target_id") == expected_destination.fetch("id")
          raise "#{row.fetch("file_id")}: target does not match domain policy"
        end
        if row.fetch("target_kind") == "volume"
          raise "#{row.fetch("file_id")}: unknown volume target #{row.fetch("target_id")}" unless catalog_index.volume_slugs.include?(row.fetch("target_id"))
        end
      end

      @mappings.each do |row|
        validate_required_values(row, MAPPING_COLUMNS - %w[chapter_ids], row.fetch("section_id"))
        parent_file = files_by_id[row.fetch("file_id")]
        raise "#{row.fetch("section_id")}: unknown file foreign key #{row.fetch("file_id")}" unless parent_file
        %w[repository commit target_kind target_id].each do |field|
          unless row.fetch(field) == parent_file.fetch(field)
            raise "#{row.fetch("section_id")}: #{field} disagrees with parent file"
          end
        end
        chapter_ids = row.fetch("chapter_ids").split("|").reject(&:empty?)
        if row.fetch("target_kind") == "volume"
          raise "#{row.fetch("section_id")}: volume mapping has no chapter candidates" if chapter_ids.empty?
          chapter_ids.each do |chapter_id|
            raise "#{row.fetch("section_id")}: unknown canonical chapter #{chapter_id}" unless catalog_index.chapter_ids.include?(chapter_id)
            unless catalog_index.chapter_volume_slug(chapter_id) == row.fetch("target_id")
              raise "#{row.fetch("section_id")}: chapter #{chapter_id} is outside #{row.fetch("target_id")}"
            end
          end
        elsif !chapter_ids.empty?
          raise "#{row.fetch("section_id")}: non-book disposition must not claim canonical chapters"
        end
        raise "#{row.fetch("section_id")}: heuristic mapping cannot be marked reviewed" unless row.fetch("review_status") == "unreviewed"
        source_only = row.fetch("target_kind") == "source-only"
        expected_official_state = source_only ? "not-applicable" : "required-not-linked"
        expected_verification_state = source_only ? "not-applicable" : "required-not-run"
        unless row.fetch("official_source_required") == !source_only &&
               row.fetch("official_source_state") == expected_official_state
          raise "#{row.fetch("section_id")}: invalid official-source state"
        end
        unless row.fetch("verification_required") == !source_only &&
               row.fetch("verification_state") == expected_verification_state
          raise "#{row.fetch("section_id")}: invalid verification state"
        end
      end
    end

    def duplicate_values(rows, field)
      rows.group_by { |row| row.fetch(field) }.select { |_value, group| group.length > 1 }.keys
    end

    def validate_required_values(row, fields, label)
      missing = fields.select { |field| row[field].nil? || row[field].to_s.empty? }
      raise "#{label} missing fields: #{missing.join(", ")}" unless missing.empty?
    end

    def render_public_artifacts
      artifacts = {}
      artifacts["files.csv"] = render_csv(FILE_COLUMNS, @files)
      artifacts["mappings.csv"] = render_csv(MAPPING_COLUMNS, @mappings)
      artifacts["migration-policy.md"] = migration_policy
      artifacts["README.md"] = readme
      artifacts["ADVERSARIAL-REVIEW.md"] = adversarial_review
      artifacts["catalog.yml"] = catalog(artifacts).to_yaml(line_width: -1)
      artifacts
    end

    def render_private_artifacts
      return {} unless @include_private

      {
        "README.md" => private_readme,
        "files.raw.jsonl" => @raw_files.map { |row| JSON.generate(row) }.join("\n") + "\n",
        "sections.raw.jsonl" => @raw_sections.map { |row| JSON.generate(row) }.join("\n") + "\n"
      }
    end

    def render_csv(columns, rows)
      CSV.generate(row_sep: "\n", force_quotes: true) do |csv|
        csv << columns
        rows.each do |row|
          csv << columns.map { |column| SourceInventory.csv_safe_cell(row.fetch(column, "")) }
        end
      end
    end

    def catalog(artifacts)
      {
        "schema_version" => SCHEMA_VERSION,
        "scope" => "public-hashes-sanitized-metadata-and-unreviewed-canonical-mappings",
        "determinism" => "fixed commits, fixed canonical URLs, canonical catalog FKs, normalized paths, sorted rows, SHA-256, no timestamps",
        "catalog_id" => catalog_index.catalog_id,
        "catalog_edition" => catalog_index.edition,
        "repositories" => @repositories.each_with_object({}) do |repository, memo|
          memo[repository.key] = repository_summary(repository)
        end,
        "totals" => {
          "file_count" => @files.length,
          "size_bytes" => @files.sum { |row| row.fetch("size_bytes") },
          "markdown_count" => @files.count { |row| row.fetch("type") == "md" },
          "pdf_count" => @files.count { |row| row.fetch("type") == "pdf" },
          "section_mapping_count" => @mappings.length,
          "unreviewed_mapping_count" => @mappings.count { |row| row.fetch("review_status") == "unreviewed" },
          "broad_volume_mapping_count" => @mappings.count { |row| row.fetch("mapping_confidence") == "heuristic-low" }
        },
        "counts_by_domain" => count_by(@files, "domain"),
        "counts_by_default_action" => count_by(@files, "default_action"),
        "file_counts_by_target" => count_by_composite(@files, %w[target_kind target_id]),
        "mapping_counts_by_target" => count_by_composite(@mappings, %w[target_kind target_id]),
        "mapping_counts_by_confidence" => count_by(@mappings, "mapping_confidence"),
        "mapping_counts_by_review_status" => count_by(@mappings, "review_status"),
        "public_artifacts" => artifacts.keys.sort.each_with_object({}) do |name, memo|
          memo[name] = Digest::SHA256.hexdigest(artifacts.fetch(name))
        end,
        "private_raw_ledger" => "optional-local-only-gitignored-never-publish"
      }
    end

    def repository_summary(repository)
      files = @files.select { |row| row.fetch("repository") == repository.key }
      mappings = @mappings.count { |row| row.fetch("repository") == repository.key }
      {
        "canonical_url" => repository.canonical_url,
        "commit" => repository.commit,
        "file_count" => files.length,
        "size_bytes" => files.sum { |row| row.fetch("size_bytes") },
        "markdown_count" => files.count { |row| row.fetch("type") == "md" },
        "pdf_count" => files.count { |row| row.fetch("type") == "pdf" },
        "section_mapping_count" => mappings,
        "license_state" => repository.license_state,
        "default_use" => "coverage-inventory-only"
      }
    end

    def count_by(rows, field)
      rows.group_by { |row| row.fetch(field) }.map { |key, group| [key, group.length] }.sort.to_h
    end

    def count_by_composite(rows, fields)
      rows.group_by { |row| fields.map { |field| row.fetch(field) }.join(":") }
          .map { |key, group| [key, group.length] }.sort.to_h
    end

    def readme
      summaries = @repositories.map do |repository|
        stats = repository_summary(repository)
        "| `#{repository.key}` | #{repository.canonical_url} | `#{repository.commit}` | #{stats.fetch("file_count")} | #{stats.fetch("markdown_count")} | #{stats.fetch("pdf_count")} | #{stats.fetch("section_mapping_count")} | `#{stats.fetch("license_state")}` |"
      end.join("\n")
      <<~MARKDOWN
        # 来源账本

        本目录是百科教材的公开、版权保守型来源证据层。公开文件只保存不可逆定位哈希、聚合元数据、原创概念标签和对权威课程目录的候选映射；不保存来源正文、代码、图片、PDF、完整路径或逐节原始标题。

        ## 固定来源

        | 仓库 | 规范来源 | 提交 | 文件 | Markdown | PDF | 章节候选映射 | 许可证状态 |
        | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
        #{summaries}

        全部 #{@mappings.length} 条映射的 `review_status` 都是 `unreviewed`。它们是用于防遗漏的机器候选，不代表人工确认、教材覆盖完成或技术结论正确。

        ## 公开文件

        - `catalog.yml`：固定来源、聚合计数、课程目录版本和产物摘要。
        - `files.csv`：逐文件哈希化元数据；没有原始路径。
        - `mappings.csv`：以稳定 `section_id` 为键的候选章节映射；没有原始标题或路径。
        - `migration-policy.md`：人工复核门槛和版权边界。
        - `ADVERSARIAL-REVIEW.md`：本批次的反例检查与未完成项。

        `target_kind=volume` 的 `target_id` 和全部 `chapter_ids` 都在构建时从 `curriculum/catalog.yml` 解析并验证。附录、未来扩展、来源元数据和人工分流使用不同的 `target_kind`，不再伪装成卷目录。

        ## 私有原始审计账本

        如确需核对原始位置，可用 `--include-private` 在 `sources/private/` 生成 JSONL。该目录被 `.gitignore` 排除，目录权限为 `0700`、文件权限为 `0600`，包含无许可材料的逐节标题和完整相对路径，必须保持本地或访问受控，永不进入 Git、网站、书籍、制品或分享包。原子切换使用的暂存与备份目录也必须先通过 Git 忽略检查，否则生成器拒绝写入原始账本。

        ## 重建与检查

        ```bash
        ruby scripts/build-source-inventory.rb --include-private
        ruby scripts/build-source-inventory.rb --check --include-private
        ruby tests/source_inventory/test_build_source_inventory.rb
        ```

        源仓库 URL 是生成器中的规范常量，不读取本地 `remote.origin.url`。构建不含时间戳；在受支持的 Ruby/Psych 工具链内，相同提交、目录和规则应逐字节一致。

        ## 已知边界

        - 哈希证明字节身份，不证明作者、许可、质量或合法使用权。
        - 关键词和标题评分可能误报或漏报；所有映射仍需人工逐条复核。
        - HTML、PDF、Office、归档和图片只进入文件级覆盖统计，不提取内容结构。
        - 正式采用某个知识点前，仍须补当前官方来源、版本、验证证据和版权决定。
      MARKDOWN
    end

    def migration_policy
      <<~MARKDOWN
        # 来源迁移政策

        ## 不可越过的边界

        两个来源仓库只用于发现主题和真实踩坑。未检测到根级许可证不等于“可以使用”，也不等于法律结论；默认动作始终是覆盖信号、独立研究和原创重写。

        - 不复制来源正文、代码、图片、PDF、题目、答案、项目数据或排版。
        - 不把改变量名、调整句序或升级版本号当作原创。
        - 不因哈希、候选章节 ID、文件存在或构建成功就宣称内容已经教学或验证。
        - 二进制、编译产物和构建目录默认排除；未知类型采用更严格处置。
        - 安全、认证、密钥、支付和权限材料必须重新威胁建模并独立测试。

        ## 公开层与私有层

        公开的 `files.csv` 和 `mappings.csv` 只含哈希、聚合标签和未审查的课程候选 ID。原始路径与逐节标题只能存在于 gitignored 的 `sources/private/` JSONL；该私有账本不得发布、提交或用作教材附件。生成器同时要求私有目录、原子暂存目录和备份目录被 Git 忽略，并把私有目录/文件权限限制为 `0700`/`0600`。

        ## 映射状态

        自动生成行统一使用：

        - `mapping_method=heuristic-catalog-v1` 或 `policy-disposition-v1`；
        - `review_status=unreviewed`；
        - `mapping_confidence=heuristic-*` 或 `policy`；
        - `copyright_state=*-coverage-only`。
        - `official_source_state=required-not-linked` 与 `verification_state=required-not-run`（来源元数据排除项为 `not-applicable`）。

        这些值明确表示机器候选，不表示人工确认。`heuristic-low` 会把来源节映射到整卷的全部章节候选，避免制造虚假的单章精度。

        ## 人工关闭条件

        每条来源节只有补齐以下证据，才可从迁移队列关闭：

        1. 人工选择一个或多个稳定章节 ID，或明确非书籍处置；
        2. 记录决定理由、复核者和复核状态；
        3. 至少一个当前官方/一手来源直接支持拟写结论；
        4. 区分稳定原理和版本敏感操作；
        5. 代码、命令和安全结论有独立验证；
        6. 确认只保留覆盖信号，并完成原创表达与示例；
        7. 版权不确定时回退到排除，而不是默认放宽。

        当前生成器不会伪造这些人工字段；因此 P1 公开映射完整不等于人工迁移完成。

        ## 变更与回滚

        规则变化必须全量重建并评审 `catalog.yml` 计数和映射差异。写入采用同文件系统的暂存目录与目录切换；失败时恢复旧目录。`--check` 只比较，不写入，并拒绝过期或额外的公开产物。
      MARKDOWN
    end

    def adversarial_review
      broad = @mappings.count { |row| row.fetch("mapping_confidence") == "heuristic-low" }
      non_book = @mappings.count { |row| row.fetch("target_kind") != "volume" }
      excluded_binary = @files.count do |row|
        %w[exclude-binary-asset exclude-generated-build-output coverage-only-do-not-copy].include?(row.fetch("default_action"))
      end
      <<~MARKDOWN
        # P1 来源账本对抗性复核

        ## 已自动验证

        - #{@files.length} 个 Git 跟踪文件均有哈希化处置记录；来源提交和干净工作树经过检查。
        - #{@mappings.length} 个 Markdown 标题均有稳定哈希 ID，并映射到合法课程章节候选或明确非书籍处置。
        - 所有卷和章节外键来自 `#{catalog_index.catalog_id}` / `#{catalog_index.edition}`，不存在写死的卷 slug。
        - #{excluded_binary} 个文档、二进制或生成产物采用不复制/排除动作。
        - 公开产物不含 `path`、`heading` 字段；原始账本仅可写入 gitignored 私有目录。

        ## 故意尝试推翻的结论

        - **“映射已经确认”——不成立。** #{@mappings.length} 条均为 `unreviewed`。
        - **“每条都精确落到单章”——不成立。** #{broad} 条缺乏可靠信号，保守映射到整卷候选。
        - **“全部进入正文”——不成立。** #{non_book} 条使用附录、未来扩展、来源排除或人工分流。
        - **“没有许可证就一定侵权/一定可用”——两者都不成立。** 账本只记录未发现根许可证并采用最严格迁移策略。
        - **“哈希化后不再需要版权审查”——不成立。** 哈希只降低公开账本复刻原目录的风险。

        ## 尚未验证

        - 尚未完成人工逐节复核、正式官方来源绑定或技术正确性验证。
        - 尚未取得两个来源仓库全部材料的转载授权。
        - 关键词映射仍可能出现语义误报；只有负例回归和外键完整性是自动保证。
        - Ruby/Psych 大版本变化可能改变 YAML 序列化，升级工具链后必须重跑确定性检查。

        结论：该批次可以作为公开的**未审查迁移队列**，不能作为正文完成、版权许可或人工映射完成证据。
      MARKDOWN
    end

    def private_readme
      <<~MARKDOWN
        # 私有原始来源审计账本

        本目录包含来源材料的完整相对路径和逐节原始标题，仅供受控核对。它被根 `.gitignore` 排除，禁止提交、发布、上传站点、打包进教材或发送给无访问授权的第三方。

        `file_id` 和 `section_id` 可与公开哈希化账本关联；人工复核后只把原创决定和规范章节 ID 写入公开迁移记录，不复制原始表达。
      MARKDOWN
    end

    def check_outputs!(artifacts, private_artifacts)
      raise "output directory does not exist: #{output_root}" unless output_root.directory?
      expected_public = artifacts.keys.sort
      actual_public = output_root.children.select(&:file?).map { |path| path.basename.to_s }.sort
      extra = actual_public - expected_public
      missing = expected_public - actual_public
      mismatches = []
      output_root.children.select(&:symlink?).each do |path|
        mismatches << "symbolic link is not allowed in public inventory output #{path}"
      end
      missing.each { |name| mismatches << "missing #{output_root.join(name)}" }
      extra.each { |name| mismatches << "unexpected public artifact #{output_root.join(name)}" }
      output_root.children.reject do |path|
        path.file? || (path.directory? && path.basename.to_s == "private")
      end.each do |path|
        mismatches << "unexpected public entry #{path}"
      end
      artifacts.each do |name, expected|
        path = output_root.join(name)
        next unless path.file? && !path.symlink?
        mismatches << "stale #{path}" unless Digest::SHA256.file(path).hexdigest == Digest::SHA256.hexdigest(expected)
      end

      if @include_private
        private_root = output_root.join("private")
        if private_root.directory?
          private_root.children.select(&:symlink?).each do |path|
            mismatches << "symbolic link is not allowed in private audit output #{path}"
          end
          actual_private = private_root.children.select(&:file?).map { |path| path.basename.to_s }.sort
          (actual_private - PRIVATE_FILES.sort).each do |name|
            mismatches << "unexpected private audit artifact #{private_root.join(name)}"
          end
          private_root.children.reject(&:file?).each do |path|
            mismatches << "unexpected private audit entry #{path}"
          end
        end
        PRIVATE_FILES.each do |name|
          path = private_root.join(name)
          expected = private_artifacts.fetch(name)
          if !path.file?
            mismatches << "missing private audit artifact #{path}"
          elsif path.symlink?
            next
          elsif Digest::SHA256.file(path).hexdigest != Digest::SHA256.hexdigest(expected)
            mismatches << "stale private audit artifact #{path}"
          end
        end
      end
      raise "source inventory check failed:\n- #{mismatches.join("\n- ")}" unless mismatches.empty?
    end

    def transactional_write(artifacts, private_artifacts)
      parent = output_root.parent
      FileUtils.mkdir_p(parent)
      stage = Pathname(Dir.mktmpdir(".#{output_root.basename}.stage-", parent.to_s))
      backup = parent.join(".#{output_root.basename}.backup-#{$$}")
      begin
        FileUtils.chmod(0o755, stage)
        artifacts.each { |name, content| write_file(stage.join(name), content) }
        if @include_private
          private_root = stage.join("private")
          FileUtils.mkdir_p(private_root)
          FileUtils.chmod(0o700, private_root)
          private_artifacts.each { |name, content| write_file(private_root.join(name), content, mode: 0o600) }
        elsif output_root.join("private").directory?
          FileUtils.cp_r(output_root.join("private"), stage.join("private"))
          secure_private_tree(stage.join("private"))
        end

        FileUtils.rm_rf(backup)
        File.rename(output_root, backup) if output_root.exist?
        begin
          File.rename(stage, output_root)
        rescue StandardError
          File.rename(backup, output_root) if backup.exist? && !output_root.exist?
          raise
        end
        FileUtils.rm_rf(backup)
      ensure
        FileUtils.rm_rf(stage) if stage.exist?
      end
    end

    def write_file(path, content, mode: 0o644)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, content.encode("UTF-8"))
      FileUtils.chmod(mode, path)
    end

    def secure_private_tree(root)
      Find.find(root.to_s) do |entry|
        raise "private audit ledger may not contain symbolic links: #{entry}" if File.symlink?(entry)

        FileUtils.chmod(File.directory?(entry) ? 0o700 : 0o600, entry)
      end
    end

    def print_summary
      puts(@check ? "source inventory check passed" : "source inventory built")
      puts "files=#{@files.length} markdown=#{@files.count { |row| row.fetch("type") == "md" }} pdf=#{@files.count { |row| row.fetch("type") == "pdf" }} mappings=#{@mappings.length}"
      puts "reviewed=0 unreviewed=#{@mappings.length}"
      puts "output=#{output_root}"
      puts "private_raw=#{@include_private ? "generated-gitignored" : "not-generated"}"
    end
  end

  class CLI
    def self.run(argv)
      root = File.expand_path("..", __dir__)
      options = {
        repository_paths: DEFAULT_REPOSITORIES.dup,
        expected_commits: EXPECTED_COMMITS.dup,
        output_root: File.join(root, "sources"),
        catalog_path: File.join(root, "curriculum", "catalog.yml"),
        check: false,
        include_private: false,
        quiet: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby scripts/build-source-inventory.rb [options]"
        opts.on("--note-repo PATH", "Path to the Note repository") { |value| options[:repository_paths]["note"] = value }
        opts.on("--java-note-repo PATH", "Path to the Java-Note repository") { |value| options[:repository_paths]["java-note"] = value }
        opts.on("--note-commit SHA", "Expected Note commit") { |value| options[:expected_commits]["note"] = value }
        opts.on("--java-note-commit SHA", "Expected Java-Note commit") { |value| options[:expected_commits]["java-note"] = value }
        opts.on("--catalog PATH", "Canonical curriculum catalog") { |value| options[:catalog_path] = value }
        opts.on("--output PATH", "Output directory") { |value| options[:output_root] = value }
        opts.on("--include-private", "write/check the gitignored raw audit JSONL") { options[:include_private] = true }
        opts.on("--check", "compare generated outputs without writing") { options[:check] = true }
        opts.on("--quiet", "print only failures") { options[:quiet] = true }
        opts.on("-h", "--help", "Show this help") do
          puts opts
          return 0
        end
      end
      parser.parse!(argv)
      Builder.new(**options).run
      0
    rescue OptionParser::ParseError, RuntimeError, KeyError, Psych::Exception => error
      warn "ERROR: #{error.message}"
      1
    end
  end
end

exit SourceInventory::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
