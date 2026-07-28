///|
fn main {
  let args = @env.args()
  let sample = if args.length() > 1 { args[1] } else { "hello\nworld" }
  println(@moongettext.escape_po_string(sample))
}
