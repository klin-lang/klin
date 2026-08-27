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
  version "0.1.4"

  on_macos do
    on_arm do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.4/klin-macos-arm64.tar.gz"
      sha256 "543e7ae00f15cb81f52e676f67c185ac66de06fef87ca1c4790224b07ca86f9a"
    end
    on_intel do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.4/klin-macos-amd64.tar.gz"
      sha256 "a495c5e019e34ac8077766c9c3ae2f695d1863e52aa0684a6c5c07c0b3d4b74d"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.4/klin-linux-arm64.tar.gz"
      sha256 "1bd26a2ba5a9ec63ff99bf4068a228b78663ab8168ebc798a5602d654329d389"
    end
    on_intel do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.4/klin-linux-amd64.tar.gz"
      sha256 "8dfba35577305f753e1ae9a5a72d473e567dabc72067dd31b0d066db04bf19be"
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
