///|
fn usage() -> String {
  (
    #|moongettext - GNU gettext tools in MoonBit
    #|
    #|Usage:
    #|  moon run cmd/main -- demo
    #|  moon run cmd/main -- validate <catalog.po>
    #|  moon run cmd/main -- compile <catalog.po> <catalog.mo> [--big-endian]
    #|  moon run cmd/main -- normalize <catalog.po>
    #|  moon run cmd/main -- inspect <catalog.mo>
    #|
  )
}

///|
fn require_argument(
  args : Array[String],
  index : Int,
  description : String,
) -> String raise {
  if index >= args.length() {
    raise @moongettext.Validation(message="missing \{description}\n\{usage()}")
  }
  args[index]
}

///|
fn sample_po() -> String {
  (
    #|msgid ""
    #|msgstr ""
    #|"Project-Id-Version: moongettext-demo\n"
    #|"Language: fr\n"
    #|"Content-Type: text/plain; charset=UTF-8\n"
    #|"Plural-Forms: nplurals=2; plural=(n > 1);\n"
    #|
    #|#: demo.mbt:1
    #|msgid "Open"
    #|msgstr "Ouvrir"
    #|
    #|#: demo.mbt:2
    #|msgid "file"
    #|msgid_plural "files"
    #|msgstr[0] "fichier"
    #|msgstr[1] "fichiers"
    #|
  )
}

///|
fn run_demo() -> Unit raise {
  let document = @moongettext.parse_po(sample_po())
  @moongettext.validate_po_strict(document)
  let bytes = @moongettext.compile_mo_checked(document)
  let catalog = @moongettext.Catalog::from_mo(bytes)
  println(
    "demo: \{catalog.length()} messages compiled into \{bytes.length()} MO bytes",
  )
  println("gettext(Open) = \{catalog.gettext("Open")}")
  println("ngettext(file, 1) = \{catalog.ngettext("file", "files", 1)}")
  println("ngettext(file, 3) = \{catalog.ngettext("file", "files", 3)}")
}

///|
fn validate_file(path : String) -> Int raise {
  let source = @fs.read_file_to_string(path)
  let document = @moongettext.parse_po(source)
  let findings = @moongettext.validate_po(document)
  println(@moongettext.validation_report(findings))
  if @moongettext.validation_has_errors(findings) {
    1
  } else {
    0
  }
}

///|
fn compile_file(
  input : String,
  output : String,
  endian : @moongettext.Endian,
) -> Unit raise {
  let source = @fs.read_file_to_string(input)
  let document = @moongettext.parse_po(source)
  let bytes = @moongettext.compile_mo_checked(document, endian~)
  @fs.write_bytes_to_file(output, bytes)
  let order = match endian {
    Little => "little-endian"
    Big => "big-endian"
  }
  println(
    "compiled \{document.entries.length()} PO entries to \{output} (\{bytes.length()} bytes, \{order})",
  )
}

///|
fn normalize_file(path : String) -> Unit raise {
  let source = @fs.read_file_to_string(path)
  println(@moongettext.write_po(@moongettext.parse_po(source)))
}

///|
fn inspect_file(path : String) -> Unit raise {
  let bytes = @fs.read_file_to_bytes(path)
  let endian = @moongettext.mo_endian(bytes)
  let document = @moongettext.parse_mo(bytes)
  let stats = document.statistics()
  let order = match endian {
    Little => "little-endian"
    Big => "big-endian"
  }
  println(
    "MO: \{stats.messages} messages (\{stats.plural} plural), \{bytes.length()} bytes, \{order}",
  )
  println(@moongettext.validation_report(@moongettext.validate_po(document)))
}

///|
fn run_cli(args : Array[String]) -> Int raise {
  if args.length() <= 1 {
    run_demo()
    return 0
  }
  match args[1] {
    "demo" => {
      run_demo()
      0
    }
    "validate" => validate_file(require_argument(args, 2, "input PO path"))
    "compile" => {
      let input = require_argument(args, 2, "input PO path")
      let output = require_argument(args, 3, "output MO path")
      let endian = if args.length() > 4 && args[4] == "--big-endian" {
        @moongettext.Big
      } else {
        Little
      }
      compile_file(input, output, endian)
      0
    }
    "normalize" => {
      normalize_file(require_argument(args, 2, "input PO path"))
      0
    }
    "inspect" => {
      inspect_file(require_argument(args, 2, "input MO path"))
      0
    }
    "help" | "--help" | "-h" => {
      println(usage())
      0
    }
    command =>
      raise @moongettext.Validation(
        message="unknown command '\{command}'\n\{usage()}",
      )
  }
}

///|
fn main {
  let code = try run_cli(@env.args()) catch {
    error => {
      println("error: \{Repr(error)}")
      1
    }
  } noraise {
    value => value
  }
  @sys.exit(code)
}
