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
  version "0.1.2"

  on_macos do
    on_arm do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.2/klin-macos-arm64.tar.gz"
      sha256 "9441666b6958c4f36c97b399a6507c357ab719b42dc99fdf16510393d1e6bd75"
    end
    on_intel do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.2/klin-macos-amd64.tar.gz"
      sha256 "b5f0235caecaa33d794f90bc0e8a3fd8231f03d6caa49f68b7be7901f26ffe19"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.2/klin-linux-arm64.tar.gz"
      sha256 "930730cf9f65b8783e3854605d03306da8c14e4d2ed7f5c57c7b1dba663c34c7"
    end
    on_intel do
      url "https://github.com/klin-lang/klin/releases/download/v0.1.2/klin-linux-amd64.tar.gz"
      sha256 "985e0ec067ee428f0ff2a81b79d441a829ae3f5db5b6867bdea128ba8cbfb6a4"
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
