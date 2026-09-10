extends RefCounted

## El idioma del juego.
##
## Todo el texto está escrito en español dentro del código, y el español es la
## CLAVE de la tabla de traducción (`localization/textos.csv`): con el juego en
## inglés, `TranslationServer` devuelve la línea traducida, y con el juego en
## español —o para lo que no esté traducido— devuelve la misma línea. Así no
## hay claves inventadas ni textos duplicados, y lo que falte se ve en español
## en vez de verse como una clave.
##
## Los Label y Button se traducen solos (auto_translate). Lo que se arma con
## formato —«%d/%d», «%s logro: %s»— pasa por `t()` antes de rellenarse, y los
## guiones de diálogo por `guion()`, que traduce réplica a réplica.

## Una cadena, en el idioma puesto.
static func t(texto: String) -> String:
	return TranslationServer.translate(texto)


## Un guion del Dialogue Manager, traducido línea a línea: quién habla y qué
## dice, las respuestas («- …») y nada más. Las marcas —«~ start», «=> END»,
## la sangría de las respuestas— se dejan como están.
static func guion(texto: String) -> String:
	var salida: PackedStringArray = []
	for linea in texto.split("\n"):
		var sangria := linea.substr(0, linea.length() - linea.lstrip("\t ").length())
		var t := linea.strip_edges()
		if t == "" or t.begins_with("~") or t.begins_with("=>"):
			salida.append(linea)
			continue
		if t.begins_with("- "):
			salida.append(sangria + "- " + TranslationServer.translate(t.substr(2).strip_edges()))
			continue
		var dos_puntos := t.find(": ")
		if dos_puntos > 0 and dos_puntos < 40:
			var quien := t.substr(0, dos_puntos)
			var que := t.substr(dos_puntos + 2)
			salida.append(sangria + TranslationServer.translate(quien) + ": " + TranslationServer.translate(que))
		else:
			salida.append(sangria + TranslationServer.translate(t))
	return "\n".join(salida)
