require "formula"

class Clog < Formula
  homepage "http://tasktools.org/projects/clog.html"
  url "http://taskwarrior.org/download/clog-1.1.0.tar.gz"
  sha1 "3c75a00f7d4b78f4b6b123ce33d6773b421b965b"

  depends_on "cmake" => :build

  def install
    mkdir "build"
    cd "build" do
      system "echo", *std_cmake_args
      system "cmake", "..", *std_cmake_args
      system "make install"
    end
  end

  test do
    echo "not broken" | clog
  end

end
