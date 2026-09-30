#!/usr/bin/env python3
import argparse
import json
import os
import plistlib
import sys

def main():
    parser = argparse.ArgumentParser(description="Actualiza apps.json para AltStore y verifica con Info.plist")
    parser.add_argument("--version", required=True, help="Versión de marketing (ej. 1.0)")
    parser.add_argument("--build", required=True, help="Build version (ej. 42)")
    parser.add_argument("--commit-msg", default="Actualización de Sueño", help="Mensaje del commit para localizedDescription")
    parser.add_argument("--date", required=True, help="Fecha ISO 8601")
    parser.add_argument("--download-url", required=True, help="URL de descarga del Release IPA")
    parser.add_argument("--size", type=int, required=True, help="Tamaño en bytes del IPA")
    parser.add_argument("--app-plist", required=True, help="Ruta al Info.plist del .app compilado")
    parser.add_argument("--json-path", default="apps.json", help="Ruta del archivo apps.json")
    parser.add_argument("--repo", default="", help="Repositorio (owner/repo)")

    args = parser.parse_args()

    # 1. Leer Info.plist compilado
    if not os.path.exists(args.app_plist):
        print(f"Error: No se encontró Info.plist en {args.app_plist}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(args.app_plist, "rb") as f:
            plist = plistlib.load(f)
    except Exception as e:
        print(f"Error leyendo Info.plist: {e}", file=sys.stderr)
        sys.exit(1)

    plist_version = plist.get("CFBundleShortVersionString")
    plist_build = plist.get("CFBundleVersion")

    print(f"Info.plist -> CFBundleShortVersionString: {plist_version}, CFBundleVersion: {plist_build}")
    print(f"Parámetros -> version: {args.version}, buildVersion: {args.build}")

    # Verificar que los argumentos coincidan con Info.plist antes de actualizar
    if plist_version != args.version:
        print(f"Error: La versión del argumento ({args.version}) no coincide con Info.plist ({plist_version})", file=sys.stderr)
        sys.exit(1)

    if plist_build != args.build:
        print(f"Error: El build del argumento ({args.build}) no coincide con Info.plist ({plist_build})", file=sys.stderr)
        sys.exit(1)

    # 2. Cargar o crear apps.json
    data = None
    if os.path.exists(args.json_path):
        try:
            with open(args.json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            print(f"Aviso: No se pudo leer {args.json_path}, se creará uno nuevo: {e}")

    icon_url = f"https://raw.githubusercontent.com/{args.repo}/main/Sueno/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" if args.repo else "https://raw.githubusercontent.com/sueno/main/Sueno/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

    if not data or not isinstance(data, dict):
        data = {
            "name": "Fuente de Sueño",
            "identifier": "com.eduardo.sueno.source",
            "apps": [
                {
                    "name": "Sueño",
                    "bundleIdentifier": "com.eduardo.sueno",
                    "developerName": "Eduardo",
                    "subtitle": "Calcula tu deuda de sueño y curva de energía",
                    "localizedDescription": "App para iPhone que calcula tu deuda de sueño de las últimas 14 noches, tu curva de energía del día con el modelo SAFTE y a qué hora acostarte.",
                    "iconURL": icon_url,
                    "tintColor": "#F2A541",
                    "versions": []
                }
            ]
        }

    # Asegurar estructura del app principal
    apps = data.setdefault("apps", [])
    if not apps:
        apps.append({
            "name": "Sueño",
            "bundleIdentifier": "com.eduardo.sueno",
            "developerName": "Eduardo",
            "subtitle": "Calcula tu deuda de sueño y curva de energía",
            "localizedDescription": "App para iPhone que calcula tu deuda de sueño de las últimas 14 noches, tu curva de energía del día con el modelo SAFTE y a qué hora acostarte.",
            "iconURL": icon_url,
            "tintColor": "#F2A541",
            "versions": []
        })

    target_app = apps[0]
    target_app["name"] = "Sueño"
    target_app["bundleIdentifier"] = "com.eduardo.sueno"
    target_app["developerName"] = "Eduardo"
    target_app["subtitle"] = "Calcula tu deuda de sueño y curva de energía"
    target_app["localizedDescription"] = "App para iPhone que calcula tu deuda de sueño de las últimas 14 noches, tu curva de energía del día con el modelo SAFTE y a qué hora acostarte."
    target_app["tintColor"] = "#F2A541"
    if args.repo:
        target_app["iconURL"] = icon_url

    new_version_entry = {
        "version": args.version,
        "buildVersion": args.build,
        "date": args.date,
        "localizedDescription": args.commit_msg,
        "downloadURL": args.download_url,
        "size": args.size,
        "minOSVersion": "17.0"
    }

    versions = target_app.get("versions", [])
    # Filtrar si ya existía la misma versión + build para evitar duplicados en re-ejecuciones
    versions = [v for v in versions if not (v.get("version") == args.version and v.get("buildVersion") == args.build)]

    # Insertar la nueva versión al INICIO
    versions.insert(0, new_version_entry)

    # Conservar máximo 10 versiones
    versions = versions[:10]
    target_app["versions"] = versions

    # Guardar apps.json
    with open(args.json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"apps.json actualizado exitosamente en {args.json_path} con la versión {args.version} ({args.build}). Total de versiones conservadas: {len(versions)}.")

    # 3. Verificación final de que la versión en JSON coincide con Info.plist
    top_version = target_app["versions"][0]
    if top_version["version"] != plist_version or top_version["buildVersion"] != plist_build:
        print(f"Error de verificación: La versión guardada en JSON ({top_version['version']}-{top_version['buildVersion']}) "
              f"no coincide con Info.plist ({plist_version}-{plist_build}).", file=sys.stderr)
        sys.exit(1)

    print("✅ Verificación completada: version y buildVersion coinciden exactamente con Info.plist.")

if __name__ == "__main__":
    main()
