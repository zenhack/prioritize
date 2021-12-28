FIELDS = [
    'newJob',
    'title',
    'period',
    'urgencyGrowth',
]

print(
    "module GenAccessors exposing(..)\n"
    "\n"
    "import Accessors\n"
    "\n"
)

for field in FIELDS:
    print("".join([
        field,
        " = Accessors.makeOneToOne .",
        field,
        " (\c r -> { r | ",
        field,
        " = c r.",
        field,
        " })\n\n",
    ]))
