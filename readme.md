# Scheme.jai

A small library for working with [Schemes](https://github.com/judah-caruso/schemes).


## Usage

```bash
# Manual management
mkdir vendor && cd vendor/
git clone https://github.com/judah-caruso/scheme.jai Scheme
```

```odin
#import "Basic";
#import "Scheme";

main :: () {
   file, read_ok := read_entire_file("my-scheme.svg");
   assert(read_ok);

   scheme, ok, err := read_scheme(file);
   if !ok {
      log_error("Error while reading scheme file: %", err);
      return;
   }

   log("Opened scheme '%' %", scheme.title, scheme.palette);

   // Apply/work with scheme colors
   // Scheme.c0-c7   : Scheme_Color;
   // Scheme.palette : [8]Scheme_Color;

   log("The hex value of c3 is: %", to_hex(scheme.c3));

   // Export SVG scheme from structure
   svg := export_scheme(scheme);

   log("Exported svg:\n%", svg);
}
```


## Notes

- All error strings returned by `read_scheme` are allocated with the temporary allocator.
- `read_scheme` takes an allocator argument (default: context) which is used for the title.
- `export_scheme` takes an allocator argument (default: context) which is used for the output SVG.
- `to_hex` allocates a new string using the temporary allocator.
