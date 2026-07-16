# Compatibility shim for ~/.zshrc loaders that only source ~/.aliases/*.sh.
typeset -a media_alias_files
media_alias_files=("${HOME}"/.aliases/media/*.sh(N))
for f in "${media_alias_files[@]}"; do
  source "$f"
done
