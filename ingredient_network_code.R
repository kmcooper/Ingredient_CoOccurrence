## Set variables
workingDir = "/Users/katedempsey/Documents/Research/UNO/CooperLab/ingredient_network/"

## Change to the data folder of your working directory and download
setwd(paste0(workingDir,"data"))
ret = download.file("https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv","raw_data.csv")

system(command = 'wc -l raw_data.csv')
#system('cut -f 1 raw_data.csv | uniq | wc -l')
system('cut -f 1,32,35,36,37 raw_data.csv | grep \'United States\' | uniq | wc -l')
system('cut -f 1,32,35,36,37 raw_data.csv | grep \'United States\' | uniq > raw_ingredients.txt')

getwd()
raw_ingredients = read.csv("raw_ingredients.txt",sep="\t",header = TRUE)

ingredients <- raw_ingredients[-which(raw_ingredients$ingredients_text == ""), ]
remove(raw_ingredients)

ingredients$ingredients_text <- tolower(ingredients$ingredients_text)

#Certain ingredients are followed by a percentage (i.e. "milk chocolate 32.7%"). For purposes of building our co-occurence network, we will disregard these percentages and remove them, both for US (32.7%) and European (32,7%) formatting styles.
ingredients$ingredients_text <-gsub('\\d+[.,]*\\d*\\s{0,1}%','',ingredients$ingredients_text)

#Further, we want to make similar changes to make comparability of ingredients similar.
# Remove the term "organic" from ingredients as organic is not regulated by the FDA
ingredients$ingredients_text <-gsub('organic ','',ingredients$ingredients_text, ignore.case = TRUE)
ingredients$ingredients_text <-gsub('org ','',ingredients$ingredients_text, ignore.case = TRUE)

# Remove special letters and characters and replace with standard [a-z] or otherwise
ingredients$ingredients_text <-gsub('[éèë]','e',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ï','i',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('[âà]','a',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ô','o',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('_','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('?','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\[\\]','',ingredients$ingredients_text)


# Remove the term "ingredients" as it is redundant
ingredients$ingredients_text <-gsub('ingredient[s]*\\s{0,1}\\:*','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ingrédient[s]*\\s{0,1}\\:*','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ingrédiente[ns]*\\s{0,1}\\:*','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('amount','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('serving','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nourishment','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nourishment','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('made from ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('only ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pure ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('contains less than','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('vital ','',ingredients$ingredients_text)

# Remove preparatory or provenance terms that do not affect molecular makeup of the ingredient (but may remove bacteria/pathogens)
ingredients$ingredients_text <-gsub('cultured','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pasteurized','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('distilled','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('california','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('grade a+','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('extra','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('virgin','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('free range','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('french','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('high fiber','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('low fat','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('whole ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('rolled ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('expeller ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pressed ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('raw ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('evaporated ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cow\'s milk','milk',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('non-gmo','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('refined ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('milled ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('soft ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('hard ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('toasted ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('sliced ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('mediterranean ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('peeled ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cored ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('dry ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('roasted ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('mountain ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('spring ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('diced ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('sparkling ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cooked ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('freshly made from: ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('concentrated ','',ingredients$ingredients_text)

# Remove names
ingredients$ingredients_text <-gsub('bragg\'s ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('bart \\& judy\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nagai\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('best annie\'s friends','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('annie\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('what\'s inside?','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('newman\'s own','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('dr\\.\\s*kefir\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('rockin\' poppin\'','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('hellmann\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('us grown','',ingredients$ingredients_text)

