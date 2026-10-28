extends RefCounted
# The two original IDs remain stable for existing saved profiles.
const IDS := ["male", "female", "male_young", "female_young", "male_senior", "female_senior"]
const NAMES := ["Мужчина • классический", "Женщина • классическая", "Молодой мужчина", "Молодая женщина", "Пожилой мужчина", "Пожилая женщина"]

static func index_of(id: String) -> int:
 return maxi(0, IDS.find(id))

static func model(id: String, index: int = 0) -> String:
 match id:
  "male_young": return "kaykit_Barbarian"
  "male_senior": return "kaykit_Mage"
  "female_young": return "kaykit_Rogue_Hooded"
  "female_senior": return "kaykit_Rogue"
  "female": return "kaykit_Rogue" if index % 2 == 0 else "kaykit_Rogue_Hooded"
  _: return "kaykit_Knight"

static func biology(sex: String, age: int) -> String:
 if age >= 60:
  return "male_senior" if sex == "male" else "female_senior"
 return "male" if sex == "male" else "female"
