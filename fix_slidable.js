const fs = require('fs');
const glob = require('glob');

const files = glob.sync('lib/**/*.dart');

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;

  // Replace standard synchronous onPressed for Slidable
  // We'll wrap the logic inside Future.delayed
  
  // Find cases like:
  // onPressed: (_) => ref.read(...).deleteTask(task.id),
  content = content.replace(/onPressed: \(_\) => ref\.read\(([^)]+)\)\.([a-zA-Z0-9_]+)\(([^)]+)\),/g, 
    "onPressed: (_) {\n                Future.delayed(const Duration(milliseconds: 50), () {\n                  ref.read($1).$2($3);\n                });\n              },");

  content = content.replace(/onPressed: \(context\) \{\n\s*ref\.read\(([^)]+)\)\.([a-zA-Z0-9_]+)\(([^)]+)\);\n\s*\},/g,
    "onPressed: (context) {\n                Future.delayed(const Duration(milliseconds: 50), () {\n                  ref.read($1).$2($3);\n                });\n              },");

  if (content !== original) {
    fs.writeFileSync(file, content);
    console.log(`Fixed simple slidable logic in ${file}`);
  }
});
