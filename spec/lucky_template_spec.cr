require "./spec_helper"

describe LuckyTemplate do
  around_each do |example|
    with_tempfile("tmp") do |tmp|
      Dir.mkdir_p(tmp)
      Dir.cd(tmp) do
        example.run
      end
    end
  end

  describe ".create_folder" do
    context "without block" do
      it "returns a folder" do
        LuckyTemplate.create_folder.should be_a(LuckyTemplate::Folder)
      end

      it "returned folder is not locked" do
        LuckyTemplate.create_folder.locked?.should be_false
      end
    end

    context "with block" do
      it "yields a folder and returns the folder" do
        returned_folder = LuckyTemplate.create_folder do |folder|
          folder.should be_a(LuckyTemplate::Folder)
        end
        returned_folder.should be_a(LuckyTemplate::Folder)
      end

      it "yielded folder is locked, but returned folder is not locked" do
        returned_folder = LuckyTemplate.create_folder do |folder|
          folder.locked?.should be_true
        end
        returned_folder.locked?.should be_false
      end
    end
  end

  describe ".write!" do
    context "without block" do
      it "writes folder to disk" do
        folder = LuckyTemplate.create_folder
        LuckyTemplate.write!(Path["."], folder)
      end

      it "writes folder with file to disk" do
        folder = LuckyTemplate.create_folder do |dir|
          dir.add_file(".keep")
        end
        LuckyTemplate.write!(Path["."], folder)
      end

      it "raises if folder is locked" do
        LuckyTemplate.create_folder do |folder|
          expect_raises(LuckyTemplate::Error, "folder is locked") do
            LuckyTemplate.write!(Path["."], folder)
          end
        end
      end

      it "raises if location is not an existing folder" do
        folder = LuckyTemplate.create_folder do |dir|
          dir.add_file(".keep")
        end
        File.touch(Path["./folder"])
        expect_raises(File::AlreadyExistsError) do
          LuckyTemplate.write!(Path["./folder"], folder)
        end
      end
    end

    context "with block" do
      it "writes folder to disk" do
        LuckyTemplate.write!(Path["."]) { }
      end
    end
  end

  describe ".snapshot" do
    it "returns a snapshot" do
      folder = LuckyTemplate.create_folder
      LuckyTemplate.snapshot(folder).should be_a(LuckyTemplate::Snapshot)
    end

    it "raises if folder is locked" do
      LuckyTemplate.create_folder do |folder|
        expect_raises(LuckyTemplate::Error, "folder is locked") do
          LuckyTemplate.snapshot(folder)
        end
      end
    end

    it "returns same snapshot if no changes are made to folder" do
      folder = LuckyTemplate.create_folder do |dir|
        dir.add_file(".keep")
      end
      snap1 = LuckyTemplate.snapshot(folder)
      snap2 = LuckyTemplate.snapshot(folder)
      snap2.should eq(snap1)
    end

    it "returns different snapshot if changes are made to folder" do
      folder = LuckyTemplate.create_folder do |dir|
        dir.add_file(".keep")
      end
      snap1 = LuckyTemplate.snapshot(folder)
      folder.add_file("README.md")
      snap2 = LuckyTemplate.snapshot(folder)
      snap2.should_not eq(snap1)
    end

    it "returns snapshot with POSIX paths as keys" do
      folder = LuckyTemplate.create_folder do |dir|
        dir.add_folder("parent", "child", "grandchild")
      end
      snapshot = LuckyTemplate.snapshot(folder)
      snapshot.keys.should contain("parent")
      snapshot.keys.should contain("parent/child")
      snapshot.keys.should contain("parent/child/grandchild")
    end
  end

  describe ".validate!" do
    it "returns true if folder is valid" do
      folder = LuckyTemplate.write!(Path["."]) do |dir|
        dir.add_file(".keep")
      end
      LuckyTemplate.validate!(Path["."], folder).should be_true
    end

    it "raises if a file or folder does not exist" do
      folder = LuckyTemplate.write!(Path["."]) do |dir|
        dir.add_file(".keep")
      end
      File.delete(Path["./.keep"])
      expect_raises(File::NotFoundError) do
        LuckyTemplate.validate!(Path["."], folder)
      end
    end

    it "raises if folder is locked" do
      folder = LuckyTemplate.write!(Path["."]) do |dir|
        expect_raises(LuckyTemplate::Error, "folder is locked") do
          LuckyTemplate.validate!(Path["."], dir)
        end
      end
    end
  end

  describe ".validate?" do
    it "returns true if folder is valid" do
      folder = LuckyTemplate.write!(Path["."]) do |dir|
        dir.add_file(".keep")
      end
      LuckyTemplate.validate?(Path["."], folder).should be_true
    end

    it "returns false if folder is not valid" do
      folder = LuckyTemplate.write!(Path["."]) do |dir|
        dir.add_file(".keep")
      end
      File.delete(Path["./.keep"])
      LuckyTemplate.validate?(Path["."], folder).should be_false
    end
  end

  describe "Folder" do
    describe "#add_file" do
      context "with name" do
        it "adds file with string content" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("hello.txt", "hello world with string")
          end
          File.read(Path["./hello.txt"]).should eq("hello world with string")
        end

        it "adds file with interpolated string content" do
          LuckyTemplate.write!(Path["."]) do |folder|
            name = "John"
            folder.add_file("hello.txt", "Hello #{name}")
          end
          File.read(Path["./hello.txt"]).should eq("Hello John")
        end

        it "adds file with string content using heredoc" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("hello.txt", <<-TEXT)
            hello world with heredoc
            TEXT
          end
          File.read(Path["./hello.txt"]).should eq("hello world with heredoc")
        end

        it "adds file with interpolated string content using heredoc" do
          LuckyTemplate.write!(Path["."]) do |folder|
            name = "Jane"
            folder.add_file("hello.txt", <<-TEXT)
            Hello #{name}
            TEXT
          end
          File.read(Path["./hello.txt"]).should eq("Hello Jane")
        end

        it "adds file with no content" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("hello.txt")
          end
          File.size(Path["./hello.txt"]).should eq(0)
        end

        it "adds file with block" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("hello.txt") do |io|
              io << "hello world with block"
            end
          end
          File.read(Path["./hello.txt"]).should eq("hello world with block")
        end

        it "adds file with proc" do
          LuckyTemplate.write!(Path["."]) do |folder|
            proc = LuckyTemplate::FileIO.new { |io| io << "hello world with proc" }
            folder.add_file("hello.txt", &proc)
          end
          File.read(Path["./hello.txt"]).should eq("hello world with proc")
        end

        it "adds file with class that implements Fileable" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("hello.txt", HelloWorldClass.new)
          end
          File.read(Path["./hello.txt"]).should eq("hello world with class")
        end

        it "adds file with struct that implements Fileable" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("hello.txt", HelloWorldStruct.new)
          end
          File.read(Path["./hello.txt"]).should eq("hello world with struct")
        end

        it "adds file when name is a POSIX path" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("./hello.txt")
          end
          File.size(Path["./hello.txt"]).should eq(0)
        end

        it "adds nested file when name is a POSIX path" do
          LuckyTemplate.write!(Path["."]) do |folder|
            folder.add_file("./a/b/c/hello.txt")
          end
          File.size(Path["./a/b/c/hello.txt"]).should eq(0)
        end
      end

      context "with path" do
        pending "WIP"
      end
    end

    describe "#add_folder" do
      pending "WIP"
    end

    describe "#insert_folder" do
      it "raises if folder is itself" do
        LuckyTemplate.create_folder do |folder|
          expect_raises(LuckyTemplate::Error, "folder equal to itself") do
            folder.insert_folder("folder", folder)
          end
        end
      end

      it "raises if folder is locked" do
        LuckyTemplate.create_folder do |parent|
          parent.add_folder("child") do |child|
            expect_raises(LuckyTemplate::Error, "locked folder") do
              child.insert_folder("parent", parent)
            end
          end
        end
      end

      it "raises if folder is locked by adding child folder to parent again" do
        LuckyTemplate.create_folder do |parent|
          parent.add_folder("child") do |child|
            expect_raises(LuckyTemplate::Error, "locked folder") do
              parent.insert_folder("child2", child)
            end
          end
        end
      end
    end

    describe "#locked?" do
      it "returns true if locked" do
        LuckyTemplate.create_folder do |folder|
          folder.locked?.should be_true
        end
      end

      it "returns false if not locked" do
        folder = LuckyTemplate.create_folder
        folder.locked?.should be_false
      end
    end

    describe "#empty?" do
      it "returns true on empty folder" do
        folder = LuckyTemplate.create_folder
        folder.empty?.should be_true
      end

      it "returns false on modified folder" do
        LuckyTemplate.create_folder do |folder|
          folder.add_file(".keep")
          folder.empty?.should be_false
        end
      end
    end
  end
end
