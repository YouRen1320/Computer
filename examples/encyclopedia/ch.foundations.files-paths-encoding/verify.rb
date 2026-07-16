# frozen_string_literal: true

require "pathname"
require "tmpdir"

root = Pathname(__dir__)
project = root.join("project")
target_from_example = root.join("project/data/device-note.txt").cleanpath
target_from_project = project.join("data/device-note.txt").cleanpath
expected = project.join("data/device-note.txt").cleanpath

abort "files-paths-encoding verification: FAIL: relative paths disagree" unless target_from_example == expected && target_from_project == expected
abort "files-paths-encoding verification: FAIL: target is not a file" unless expected.file?
abort "files-paths-encoding verification: FAIL: hidden-name fixture missing" unless project.join(".factorycare-note").file?
abort "files-paths-encoding verification: FAIL: double extension fixture missing" unless project.join("config.json.txt").basename.to_s.end_with?(".json.txt")

bytes = expected.binread
text = bytes.force_encoding(Encoding::UTF_8)
abort "files-paths-encoding verification: FAIL: invalid UTF-8" unless text.valid_encoding?
abort "files-paths-encoding verification: FAIL: Chinese round trip mismatch" unless text.include?("设备：一号循环泵") && text.encode(Encoding::UTF_8).bytes == bytes.bytes
abort "files-paths-encoding verification: FAIL: committed fixture contains CRLF" if bytes.include?("\r\n")
abort "files-paths-encoding verification: FAIL: committed fixture is not LF text" unless bytes.include?("\n")

sample = "设备：泵站\n状态：运行\n"
Dir.mktmpdir("factorycare-encoding-") do |dir|
  lf = File.join(dir, "lf.txt")
  crlf = File.join(dir, "crlf.txt")
  File.binwrite(lf, sample)
  File.binwrite(crlf, sample.gsub("\n", "\r\n"))
  abort "files-paths-encoding verification: FAIL: LF/CRLF should differ" if File.binread(lf) == File.binread(crlf)
  abort "files-paths-encoding verification: FAIL: LF marker missing" unless File.binread(lf).include?("\n")
  abort "files-paths-encoding verification: FAIL: CRLF marker missing" unless File.binread(crlf).include?("\r\n")
end

visible = "A修🔧"
abort "files-paths-encoding verification: FAIL: UTF-8 byte oracle changed" unless visible.encode(Encoding::UTF_8).bytesize == 8

puts "paths: two origins resolve to project/data/device-note.txt"
puts "names: hidden and double-extension fixtures observed"
puts "UTF-8: Chinese round trip preserved; A修🔧=8 bytes"
puts "line endings: LF and CRLF byte sequences differ"
puts "files-paths-encoding verification: PASS"
