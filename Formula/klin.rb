# typed: false
# frozen_string_literal: true

# Homebrew formula for the Klin compiler (issue 067).
#
# Stable = prebuilt GitHub Release (no Dart).
# HEAD = build from main (`dart compile exe`; needs dart-lang/dart).
#
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
  version "0.1.3"

  on_macos do
    on_arm do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.3/klin-macos-arm64.tar.gz"
      sha256 "103d71b3b18ab195b2375dc5304396096ca6fc7e02b6890b47a98d10c2ec38fb"
    end
    on_intel do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.3/klin-macos-amd64.tar.gz"
      sha256 "55ba931a9dd1b08ef2191434205b2f666f7aadb5262f8b98ff032e75469a9a08"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.3/klin-linux-arm64.tar.gz"
      sha256 "d637fe29e752283998a7835320460335943504f2b1cf80378d49dd2738c3df58"
    end
    on_intel do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.3/klin-linux-amd64.tar.gz"
      sha256 "a8c68ab1870826c3152e23c75a0baf30574298686c94abecc7038d0f964284fb"
    end
  end

  head do
    url "https://github.com/klin-lang/klin.git", branch: "main"
    depends_on "dart-lang/dart/dart" => :build
  end

  def install
    if build.head?
      system "dart", "pub", "get"
      system "dart", "compile", "exe", "bin/klin.dart", "-o", "klin"
    end
    bin.install "klin"
    (pkgshare/"stdlib").install Dir["stdlib/*"]
    (pkgshare/"templates").install Dir["templates/*"]
  end

  def caveats
    <<~EOS
      Klin needs a host C compiler (gcc, clang, or tcc) on PATH for `klin run`.

      On macOS, Homebrew also needs current Xcode Command Line Tools (CLT),
      even for this prebuilt bottle (no Dart). A new OS can fail with
      "CLT does not support macOS …" — update CLT via Software Update or
      `xcode-select --install`, then retry. That is Apple/Homebrew, not Klin.

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
