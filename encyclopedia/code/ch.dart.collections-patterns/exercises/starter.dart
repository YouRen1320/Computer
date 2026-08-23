List<String> preserveTimeline(List<String> events) {
  // TODO：Set 会丢失重复事件，普通 toList 也没有建立只读边界。
  return events.toSet().toList();
}
