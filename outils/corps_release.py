"""Fabrique le corps d'une release : le lien d'abord, la section ensuite.

Le bloc « Assets » de GitHub est rendu SOUS le corps, a une position qu'on ne
choisit pas. Coller tout NOTES-DE-VERSION.md l'enterrait sous cinq cents
lignes. On extrait donc la seule section utile, et on met le telechargement en
premiere ligne.
"""
import io
import re
import sys

version = sys.argv[1]
notes = io.open("NOTES-DE-VERSION.md", encoding="utf-8").read()
motif = r"(?ms)^## %s\b.*?(?=^## |\Z)" % re.escape(version)
trouve = re.search(motif, notes)
section = trouve.group(0).strip() if trouve else "Voir NOTES-DE-VERSION.md."

depot = "https://github.com/BenjaminSimonetMrBleinx/bg"
zip_ = "BG-%s-windows.zip" % version
lien = "%s/releases/download/v%s/%s" % (depot, version, zip_)

io.open(".tmp/corps.md", "w", encoding="utf-8").write(
    "## [Telecharger le jeu (Windows)](%s)\n\n"
    "Un zip, un exe dedans, double-clic. Rien a installer.\n\n"
    "Windows dira « editeur inconnu » : l'executable n'est pas signe.\n"
    "**Informations complementaires -> Executer quand meme.**\n\n"
    "---\n\n%s\n" % (lien, section))
print("section trouvee : %s" % ("oui" if trouve else "NON"))
print("%d caracteres" % len(section))
