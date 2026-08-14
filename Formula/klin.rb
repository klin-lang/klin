# typed: false
# frozen_string_literal: true

# Homebrew formula for the Klin compiler (issue 067).
#
# Tap (recommended):
#   brew tap dart-lang/dart
#   brew trust --formula dart-lang/dart/dart   # Homebrew 6+
#   brew install klin-lang/klin/klin
#   brew install --HEAD klin-lang/klin/klin
#
# From this clone:
#   brew install --formula Formula/klin.rb
#   brew install --HEAD --formula Formula/klin.rb
# See docs/17-homebrew.md. Keep in sync with klin-lang/homebrew-klin.
class Klin < Formula
  desc "Systems language that compiles to C"
  homepage "https://github.com/klin-lang/klin"
  license "MIT"
  # Pin the version-bump commit: GitHub may serve a stale
  # refs/tags/vX.Y.Z.tar.gz after a tag is moved.
  url "https://github.com/klin-lang/klin/archive/5e3ef4bfba3a61369dad862e6682c831eed480d3.tar.gz"
  sha256 "0f4310746e32b0acaacaa41c2d548ecf51adba4942ae5dad7a47a641ab4498e0"
  version "0.1.2"

  head "https://github.com/klin-lang/klin.git", branch: "main"

  depends_on "dart-lang/dart/dart" => :build

  def install
    system "dart", "pub", "get"
    system "dart", "compile", "exe", "bin/klin.dart", "-o", "klin"
    bin.install "klin"
    (pkgshare/"stdlib").install Dir["stdlib/*"]
    (pkgshare/"templates").install Dir["templates/*"]
  end

  def caveats
    <<~EOS
      Klin needs a host C compiler (gcc, clang, or tcc) on PATH for `klin run`.

      Stdlib is installed at:
        #{pkgshare}/stdlib
      Board scaffolds (`klin init`) at:
        #{pkgshare}/templates
      (`klin` discovers them next to the binary / under share/klin).
    EOS
  end

  test do
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/klin --version"))
    (testpath/"hello.kl").write <<~EOS
      fn main() {}
    EOS
    system bin/"klin", "--emit-c", testpath/"hello.kl"
    assert_path_exists testpath/"out/hello.c"
  end
end
