import os

def generate_dump(root_dir, output_file):
    with open(output_file, 'w', encoding='utf-8') as outfile:
        files_to_dump = ['pubspec.yaml', 'README.md']
        for file in files_to_dump:
            path = os.path.join(root_dir, file)
            if os.path.exists(path):
                outfile.write(f"--- {file} ---\n")
                with open(path, 'r', encoding='utf-8') as infile:
                    outfile.write(infile.read())
                outfile.write("\n\n")

        lib_dir = os.path.join(root_dir, 'lib')
        for dirpath, _, filenames in os.walk(lib_dir):
            for filename in filenames:
                if filename.endswith('.dart'):
                    file_path = os.path.join(dirpath, filename)
                    relative_path = os.path.relpath(file_path, root_dir)
                    outfile.write(f"--- {relative_path.replace(os.sep, '/')} ---\n")
                    try:
                        with open(file_path, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"Error reading file: {e}\n")
                    outfile.write("\n\n")

if __name__ == '__main__':
    generate_dump('.', 'code_dump.txt')
