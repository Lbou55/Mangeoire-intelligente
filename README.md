# 🐄 Mangeoire Intelligente

> Conception et réalisation d'une mangeoire intelligente capable d'identifier automatiquement les animaux, de distribuer une ration personnalisée et de suivre individuellement leur comportement alimentaire.

---

## 📖 Description

Ce projet consiste à concevoir et réaliser une **mangeoire intelligente** capable d'identifier automatiquement les animaux, de distribuer une ration personnalisée et de suivre individuellement leur comportement alimentaire.

Grâce à des **capteurs**, une **architecture IoT** et un **module d'intelligence artificielle**, le système collectera et analysera, pour chaque animal :

- ⚖️ La quantité distribuée et la quantité estimée consommée
- 🔢 Le nombre et la durée des visites
- 🕒 Les horaires de passage
- 🚫 Les visites sans consommation
- 📈 L'évolution de la consommation sur plusieurs jours

Une **caméra** pourra également être utilisée, en option, pour confirmer la présence de l'animal à la mangeoire.

L'analyse de ces données permettra d'établir un **profil alimentaire individuel**, de détecter d'éventuelles **baisses persistantes de l'appétit** et d'**alerter l'éleveur**.

Une **application mobile** permettra de superviser la mangeoire, consulter les données, recevoir les alertes et gérer les paramètres du système à distance.

---

## 🎯 Objectifs du projet

### 🧩 Backend modulaire
Un backend organisé en **services ou modules indépendants** pour faciliter la maintenance, l'évolution et l'ajout de fonctionnalités.

### 🗂️ Gestion des données
Gestion complète de :
- Les animaux
- Les mangeoires
- Les rations
- Les distributions
- Les mesures collectées
- Les alertes
- Les utilisateurs
- Les prévisions de réapprovisionnement

### 📡 Communication IoT
Communication avec les **dispositifs IoT** et transmission des événements en **temps réel** vers l'application mobile.

### 📚 Dépôt Git documenté
Un dépôt Git contenant :
- Le code source
- L'organisation des modules
- Les fichiers de configuration
- Les instructions d'installation et d'exécution
- Une documentation technique de l'architecture, des API et des flux de données

### 🛠️ Maquette fonctionnelle
Réalisation d'une **maquette fonctionnelle** intégrant un système de distribution automatisé.

---

## 🏗️ Architecture prévue

| Composant | Rôle |
|-----------|------|
| 🐾 Capteurs | Détection et identification des animaux |
| 📷 Caméra (option) | Confirmation de la présence à la mangeoire |
| 🧠 Module IA | Analyse du comportement alimentaire |
| ⚙️ Backend modulaire | Gestion des données et des services |
| 📱 Application mobile | Supervision, alertes et paramétrage |
| 🌐 IoT | Communication temps réel |

---

## 🚀 Installation et exécution

> 📌 Les instructions détaillées seront ajoutées au fur et à mesure de l'avancement du projet.

```bash
# Cloner le dépôt
git clone https://github.com/VOTRE-USERNAME/Mangeoire-intelligente.git

# Accéder au dossier
cd Mangeoire-intelligente
