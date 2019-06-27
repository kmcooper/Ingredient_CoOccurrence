
# The Ingredient Co-occurrence Network of packaged foods distributed in the United States
Title: "Open Food Database: Ingredient Co-Occurence Network"  
Author: "Kate Cooper"  
Creation date: "2/28/2019"  
Last updated: "5/30/2019"  
Output: html_document   


The following presents a detailed and reproducible methodology of how the ingredient co-occurrence network from the Open Food Database was created. Please direct any questions, comments, or concerns to kmcooper [at] unomaha [dot] edu.

## 1. Data Download 
The data used for this analysis was downloaded from https://world.openfoodfacts.org/data on 03-21-2019 at 9:57am as a CSV file. The file folder hierarchy I have set up assumes you are in your home directory and have created a folder called `ingredient_network` with subfolders `ingredient_network/data` and `ingredient_network/code`. All code needed for the `ingredient_network/code` folder is available on the Github.

**Environment setup:**  
1. Set your working directory as the variable `workingDir`  
2. The code assumes in your working directory, you have subfolders:  `*workingDir/data*` and `*workingDir/code*`  

You will need to set each of the following variables:
* `workingDir`: The main directory where you want to work; I used `/ingredient_network/` 
* `dataDir`: This should point to the location of the `workingDir/data/` directory
* `codeDir`: This should point to the location of the `workingDir/code/` directory
* `hash_infile`: The name of the file you will use to create the ingredient network
* `hash_outfile`: The name of the file containing a hash of ingredients as keys and count as values
* `network_rawfile`: The name of the network .sif file generated from the code below



```python
#
## Set variables
#

#Preferred working directory
workingDir = "/Users/katedempsey/Documents/Research/UNO/CooperLab/ingredient_network/"

#Where data and code are stored
dataDir = "/Users/katedempsey/Documents/Research/UNO/CooperLab/ingredient_network/data/"
codeDir = "/Users/katedempsey/Documents/Research/UNO/CooperLab/ingredient_network/code/"

#Names you would like to give these files, including
# The ingredients file output from the R script (after pre-processing)
hash_infile = "ingredients.tab"

# The ingredient hash file (counting occurrence of ingredients)
hash_outfile = "ingredients.hash.txt"

#The name of the co-occurrence network 
network_rawfile = "ingredients.network.sif"

#The name of the co-occurrence network that has been filtered for only highly co-occurring ingredients
parsed_network_rawfile = "ingredients.network.parsed.sif"
#The threshold to be used to determine when an ingredient is "highly co-occurring"
edge_weight_threshold = 2000

```

At time of download (March 2019), the CSV file downloaded was 2.21GB, so plan accordingly if you need space. The file itself contained 798,919 lines by wordcount and is tab-delimited.


```python
#
## Change to the data directory and download the file from the Open Food Database
#
setwd(paste0(workingDir,"data"))
ret = download.file("https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv","raw_data.csv")
system('wc -l raw_data.csv')

```

The dataset itself contains a lot of information; at this exploratory stage we only would like to investigate ingredients per product.   
We also have to check the following:
* Are there dupliate products in the data?
* Are all ingredients named in the same way?

First, we will check if there are duplicates by barcode, the first column in the dataset. We will search only for foods sold in the United States (column 32). We also want to include the ingredients (columnt 35), and any allergens that may be noted (columns 36 and 37).


```python
system('cut -f 1,32,35,36,37 raw_data.csv | grep \'United States\' | uniq | wc -l')
```

We want to look at product by barcode as a unique ID for the product and we will make our ingredient network by comparing ingredients from the "ingredients" text in column 35, so in the next steps we extract columns 1 and 35 only from the data, and remove duplicates. This cuts our file, now named `raw_ingredients.txt` down to a much more manageable size of 38.5MB.


```python
system('cut -f 1,32,35 raw_data.csv | grep \'^\\d*\tUnited States\t.*\' | cut -f 1,3 > raw_ingredients.txt ')
```

We note that there are 174,785 rows (unique barcodes for foods in the United States) listed in our raw_ingredients file. It is assumed that entries into the Open Food Database are not reviewed for correctness [citation needed], but the 2004 Food Allergen Labeling Consumer Protection Act (FALCPA), which took effect in January 2006, requires all food labels in the United States to identify if a product contains one of the eight major allergens. ([Source](https://www.fda.gov/food/guidanceregulation/guidancedocumentsregulatoryinformation/allergens/ucm106890.htm))


```python
system('cut -f 1 raw_ingredients.txt | uniq | wc -l')
```

## 2. Data Pre-processing
Next, we want to remove any barcodes that do not have ingredients associated with them.   
To do this, lets read the file into R and begin manipulating it in memory.


```python
raw_ingredients = read.csv("raw_ingredients.txt",sep="\t",header = TRUE)
names(raw_ingredients) <- c("barcode","ingredients_text")
```

This should result in a dataframe called `raw_ingredients` that contains 499,879 observations of 2 variables. Next, we remove duplicates by removing rows for which `ingredients_text` is empty.


```python
ingredients <- as.data.frame(raw_ingredients[-which(raw_ingredients$ingredients_text == ""), ])

# You can now remove the raw_ingredients variable 
# if you are feeling confident in the reproducibility of your project
# To do this, uncomment the command below

#remove(raw_ingredients)

```

Once this is complete, we can begin to investigate and compare ingredients. Taking a brief look at the data, the first challenge to overcome is the case of the text; evaluating "Salt" and "salt" as equal ingredients will be easier if they are written in the same case. So next we change the ingredients list to all lowercase.


```python
ingredients$ingredients_text <- tolower(ingredients$ingredients_text)
```

Certain ingredients are followed by a percentage (i.e. "milk chocolate 32.7%"). For purposes of building our co-occurence network, we will disregard these percentages and remove them, both for US (32.7%) and European (32,7%) formatting styles.


```python
ingredients$ingredients_text <-gsub('\\d+[.,]*\\d*\\s{0,1}%','',ingredients$ingredients_text)
```

Further, we want to make similar changes in formatting of special characters to typical characters to make comparability of ingredients similar. For example, we want to remove the term "organic" from ingredients as organic is not regulated by the FDA.


```python
ingredients$ingredients_text <-gsub('organic ','',ingredients$ingredients_text, ignore.case = TRUE)
ingredients$ingredients_text <-gsub('org ','',ingredients$ingredients_text, ignore.case = TRUE)
ingredients$ingredients_text <-gsub('certified organic','',ingredients$ingredients_text, ignore.case = TRUE)
```

### 2.1 Remove special letters and characters and replace with standard [a-z] or otherwise


```python
ingredients$ingredients_text <-gsub('[éèë]','e',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ï','i',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('[âà]','a',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ô','o',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('_','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('?','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\[\\]','',ingredients$ingredients_text)
```

### 2.2 Remove the term "ingredients" as it is redundant


```python
ingredients$ingredients_text <-gsub('ingredient[s]*\\s{0,1}\\:*','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ingrédient[s]*\\s{0,1}\\:*','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ingrédiente[ns]*\\s{0,1}\\:*','',ingredients$ingredients_text)
```

### 2.3 Remove preparatory, quantities, or provenance terms 


```python
ingredients$ingredients_text <-gsub('amount','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('serving','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nourishment','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nourishment','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('made from ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('only ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pure ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('contains less than','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('vital ','',ingredients$ingredients_text)
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
ingredients$ingredients_text <-gsub('sparkling','carbonated',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cooked ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('freshly made from: ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('concentrated ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('stone-ground ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('partially hydrogenated','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('steel-cut ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('steel cut ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('thick cut ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('thick-cut ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('gourmet ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('fresh ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('frozen ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('natural ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('non-genetically modified ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('genetically modified','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('and nothing else','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('love ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nothing ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('italian ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('imported ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('hand-picked ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('dried ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('crushed ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('added to preserve freshness','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('for freshness','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('to preserve freshness','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('mechanically','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('mini','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('naturally','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('h2o','water',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\*','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('as a preservative','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('juice from','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('exclusively','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ground','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('shaved','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('kosher','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('ripe','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\.','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('nitrogen-flushed to maintain freshness','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('farm-raised','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('boneless','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('skinless','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('wild caught','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('parboiled','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('preparboiled','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('individually wrapped','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('all nat','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('wq all nat','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('young','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('aged','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('premium','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('added to retain color','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('blend of','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('in shell','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('with their juices','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('selected ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('with calcium ascorbate to promote whiteness','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('to promote freshness','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('not from concentrate','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('for color','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('real','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('propellant-free','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('gluten-free','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('grass-fed','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('grass fed','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('modified','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pitted','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('reconstituted','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cage\\-free','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cage free','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('free\\-range','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('freeze-','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('wild-harvested','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('contains:','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('flavors','flavor',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('less than','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('of:','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('filtered','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('contents:','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pre-washed','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('in-shell','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('in-the-shell','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('carragenan','carrageenan',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('carrageena','carrageenan',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('carrageenen','carrageenan',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('carrageen','carrageenan',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('enriched','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('unbleached','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('bleached','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('mono and diglycerides','monoglycerides and diglycerides',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('or less of the following','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('or less of each of the following','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('or less of','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('or less','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('distributed by','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('the','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('contains','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('with','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('textured','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('more of','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('following','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('product','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('strach','starch',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('emulsidiers','emulsifiers',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('occurring','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('or of following','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\(\\)','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('defatted','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('fractionated','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('hydrogenated','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('preserved','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('dry','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('modified','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('partially','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('cultured','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('or less of each of the following','',ingredients$ingredients_text)
```

### 2.4 Remove names


```python
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
ingredients$ingredients_text <-gsub('us grown ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('new zealand ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('orville redenbacher\'s ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('opal ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('of modena','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('(sourced from the united kingdom)','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub(' may contain a blend of united states, brazilian, mexican, belize and south african concentrates.','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('from emilia romagna.','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('spanish','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('himalayan','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('irish\\-style','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('scott\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('pedro ximenez','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('best','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('friends','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('teacher\'s ','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('barley\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('baker\'s','bakers',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('brewer\'s','brewers',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('sheep\'s','sheeps',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('kroger co','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('confectioner\'s','confectioners',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('trader joe\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('m\\&m\'s','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('m\\,m\'s','',ingredients$ingredients_text)

```

### 2.5 Prepare for hashing by removing non-alphabetic special characters


```python
ingredients$ingredients_text <-gsub('&','and',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\]',')',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\[',')',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\}',')',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\{',')',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub(';',',',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub(':',',',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('-','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('-','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('@','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('#','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('!','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\/',' or ',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\|','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('\\%','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('†','',ingredients$ingredients_text)
ingredients$ingredients_text <-gsub('`','',ingredients$ingredients_text)
```

## 3. Create a simple co-occurrence network
Next, we want to create a co-occurrence network, where nodes represent ingredients, and an edge drawn between the two nodes will represent a food where the two ingredients co-occur in the ingredients list. We will keep track of the number of times each co-occurrence edge occurs with a simple count. I have written two scripts (`ingredient_hash.pl` and `ingredient_network.pl`) located in the `workingDir/code/` directory that will create a hash of all ingredients and a count of their overall occurrence, as well as the co-occurrence network.


### 3.1 Write the ingredients to a .tab file and run the perl scripts


```python
write.table(ingredients, file = hash_infile,sep='\t',eol='\n',quote=FALSE,append=FALSE,row.names = FALSE)

#Create an ingredient hash and an ingredient network with the scripts provided on this repository
make_hash_command = paste0("perl ",codeDir,"ingredient_hash.pl ",dataDir,hash_infile," ",dataDir,hash_outfile)
system(make_hash_command)
make_network_command = paste0("perl ",codeDir,"ingredient_network.pl ",dataDir,hash_infile," ",dataDir,network_rawfile)
system(make_network_command)
```

## 4. Basic Network Analysis in R with igraph
Next, we want to read in the network and find out what its like! To do so, we will utilize igraph's network analysis capabilities in R. If you do not have igraph installed, you will need to do so before you can successfully continue by uncommenting the line below:

igraph Online Documentation: [Source](https://igraph.org/)


```python
#Remember, only perform this step if you do not have igraph already installed
install.packages("igraph")
```

### 4.1 Read in the network and remove duplicate edges and self-loops


```python
library(igraph)
g_data <- read.csv(network_rawfile,sep = " ",header = F,as.is = T,col.names = c("v1","v2","weight"))
g <- graph_from_data_frame(g_data)

# Check that the graph is weighted
# Should say TRUE
is_weighted(g)

# Check that the graph is not directed
# Should say FALSE
is.directed(g)

#Is the graph totally connected?
# Should say FALSE
is.connected(g)

#
# Remove loops and multiple edges
#
g <-simplify(g,remove.multiple = T,remove.loops = T)
```

### 4.2 Gather network descriptives (Table 3)


```python
#Get number of nodes, edges, and edge density
length(V(g))
length(E(g))
graph.density(g)

# Get the transitivity or clustering coefficient
cc <- transitivity(g,type="global")

# Is the graph totally connected? We expect not.
is.connected(g)

# Centrality Measures
# Assortativity
ass <- assortativity_degree(g, directed=F)

# Closeness
close <- closeness(g, mode="all", weights=NA)

# Eigenvector centrality
eigen <- eigen_centrality(g, directed=FALSE, weights=NA)

#
#  Note: The commands below take time since the network is large, 
# so only uncomment if you can step away
#

# Get the diameter, using edge weights
#diam <- diameter(g,directed=FALSE,weights=E(g)$weight)

# Betweenness centrality
#bet <- betweenness(g, directed=FALSE, weights=NA)

```

### 4.3 Examine and plot the degree distribution (Figure 1A)


```python
deg.dist <- degree.distribution(g,cumulative = TRUE,mode="all")

#Plot the degree distribution as calculated
#This will plot the graph shown in Figure 1A
plot(deg.dist, main = "Degree Distribution, only top 1000 nodes by degree shown",
     col="darkblue",pch=10,cex=0.75,xlab="Degree", ylab="Cumulative Frequency",xlim=c(0,1000))

# Plot the log-log of the degree distribution
# This is just a re-statement of the figure in 1A but is not presented in the manuscript
plot(log(deg.dist,base=10), main = "Degree Distribution of the Ingredient Co-Occurence Network",
     col="darkblue",pch=10,cex=0.75,xlab="Log10(Degree)", ylab="Log10(Cumulative Frequency)")
```

We can perform a number of tests to determine if the network itself is scale-free, although due to the incomplete nature of the source database we do not formally report on the "scale-free" nature of the network itself. One test you may run, however, is the Kolmogorov-Smirnov tests of degree-distributions in simulated scale-free and random networks to see how their distributions compare. We share some simple code to do this below.


```python
#
# Compare the degree distribution of the ingredient co-occurrence network against
# a random Erdos Reyni (random) graph and a Barabasi preferential attachment simulated graph
#

# Create the graphs to compare against, an "ab" (Albert-Barabasi) network and an "er"(Erdös-Reyni) network
random.er.graph = erdos.renyi.game(n=as.numeric(length(V(g))), p.or.m = 1/1175,directed = F, loops = F)
random.ab.graph = barabasi.game(n=length(V(g)),m=37,directed=F)

# Compare vertex count
length(V(g))
length(V(random.ab.graph))
length(V(random.er.graph))

# Compare the edge count
length(E(g))
length(E(random.ab.graph))
length(E(random.er.graph))

# Compare the histograms
hist(degree(g),xlim=c(0,6000))
hist(degree(random.ab.graph))
hist(degree(random.er.graph))

# Generate degree distributions for the random graphs
random.er.degdist = degree.distribution(random.er.graph,cumulative=T,mode='all')
random.ab.degdist = degree.distribution(random.ab.graph,cumulative=T,mode='all')

# Perform the Kolmogorov Smirnov tests of the real graph against the random graphs
ks.test(deg.dist,random.er.degdist)
ks.test(deg.dist,random.ab.degdist)
```

### 4.4 Examine the density of an induced subgraph from top K nodes (Figure 1B)


```python
#
#Get the top X nodes by degree and their edge density
#

#Obtain the degrees for all nodes in the graph
deg <- as.data.frame(degree(g, mode="all"))
names(deg)= c("degree")
deg$vertex_id = V(g)

#Sort the dataframe by decreasing order (highest degree nodes will be first)
deg <- deg[order(deg$degree,decreasing = T),]

#We begin by examining the top 3 nodes and then increase that size by intervals, see below
top_x = 3

#Create new empty lists to hold incoming data
hub_list = list()   #A list for the hub nodes
k_list = list()     #A list for keeping track of what values of k we have tried
den_list = list()   #A list for the densities of each induced subgraph we examine
stop = False        #A stop condition to tell us when we have sampled enough of the network

# This loop will run until we have sampled the top 5000 nodes in intervals
while(stop == FALSE){
  #Sanity check print statement to know your progress (its not fast, but not too slow either)
  print(c("at ",top_x))
    
  #Create a list of the top x nodes by degree
  for(i in c(1:top_x)){
    hub_list = c(hub_list,deg[i,]$vertex_id)
  }
    
  #Get the induced subgraph of the top x hub nodes in the network
  subg <- induced_subgraph(g,vids=c(hub_list))
  subg <- as.undirected(subg, mode= "collapse")
  
  #Reset the hub_list if you havent already
  hub_list=list()
    
  #Add this value of k to the list for use in plotting
  k_list = c(k_list,top_x)
   
  #Get the density of the induced subgraph used above and add it to our list of subgraph densities for k  
  den_list = c(den_list,as.numeric(graph.density(subg,loops = F)))
   
  #Start with k = 3, then go to use the top 50 nodes, increase by 50 nodes at each step until we hit 5000 nodes  
  if(top_x ==3){
    top_x = 50
  }else{
    top_x = top_x+50
  }
  if(top_x >= 5000){
    stop=TRUE
  }
}

#Round the density list for better plotting
round(den_list,digits=2)

#Plot the sampled density of the top k nodes
#This will result in the plot shown in Figure 1B
plot(k_list,den_list,type = "o",
     xlab="Top k Nodes by Degree",
     ylab="Density of the Induced Subgraph of the Top k Nodes",
     col="darkgreen",cex=0.90,pch=19,
     main = "Sampled Edge Density of the Top k Nodes"
)
```

We can use the lists created above to answer the following questions - when do we hit the (arbitrarily chosen) threshold for subgraphs with 90% density or higher?


```python
#Top 400 nodes are 90%+ density; we see the difference at the split between 400 and 450 nodes.
#90% density threshold is chosen arbitrarily
den_list[9]
k_list[9]

den_list[10]
k_list[10]
```

How many edges are represented in the top 400 nodes in the graph?


```python
top_x = 400
hub_list = list()
for(i in c(1:top_x)){
    hub_list = c(hub_list,deg[i,]$vertex_id)
}
#Get the induced subgraph of the top i hub nodes in the network
subg <- induced_subgraph(g,vids=c(hub_list))
subg <- as.undirected(subg, mode= "collapse")

#This number should be 400
length(V(subg))

#How many edges in the induced subgraph by top 400 nodes? Whats the graph density?
graph.density(subg)

```

How many edges are represented in the top 5000 nodes in the graph?


```python
#
#How many edges are represented in the top 5000 nodes in the graph?
#
top_x = 5000
hub_list = list()
for(i in c(1:top_x)){
  hub_list = c(hub_list,deg[i,]$vertex_id)
}
#Get the induced subgraph of the top i hub nodes in the network
subg <- induced_subgraph(g,vids=c(hub_list))
subg <- as.undirected(subg, mode= "collapse")

#This number should be 400
length(V(subg))

#How many edges in the induced subgraph by top 5000 nodes? Whats the graph density?
graph.density(subg)
```

### 4.5 Examine the network with only top 20 nodes (Figure 2)
The code below will retrieve the top 20 nodes by degree, create the induced subgraph, and print it out to be imported into Cytoscape for visualization. We chose to use Cytoscape for network visualization over the plotting capabilities in R only for personal preference for a point-and-click interface at this stage.


```python
#
#Get the induced subgraph for the top 500 nodes by degree and their edge density
#
deg <- as.data.frame(degree(g, mode="all"))
names(deg)= c("degree")
deg$vertex_id = V(g)
deg <- deg[order(deg$degree,decreasing = T),]
top_x = 20
hub_list = list()
for(i in c(1:top_x)){
  hub_list = c(hub_list,deg[i,]$vertex_id)
}

#Get the induced subgraph of the top i hub nodes in the network
subg <- induced_subgraph(g,vids=c(hub_list))
subg <- as.undirected(subg, mode= "collapse")
write.graph(subg,file = paste0("top_",top_x,"_network.txt"),format="ncol")
write.csv(degree(subg),file = paste0("top_",top_x,"_node_degree.txt"))
```

### 4.6 Examine the network with only edge weights >= 2000 (Figure 3)
The code below will parse the network file for only edge weights >= 2000, analyze it in R with igraph() functions,  and output it to imported into Cytoscape for visualization. We chose to use Cytoscape for network visualization over the plotting capabilities in R only for personal preference for a point-and-click interface at this stage. Some of the network descriptives calculated below are not reported in the manuscript to avoid being long-winded, but they may be of interest or use so we included them here.


```python
# 
# Parse the network so only edges with weights higher than 2000 are used
# This step may take a few minutes
#
parse_network_command = paste0("perl ",codeDir,"parse_network_by_weight.pl ",dataDir,network_rawfile," ",dataDir,parsed_network_rawfile," ",edge_weight_threshold)
system(parse_network_command)

#
# Read in the parsed network
#
g_data <- read.csv(parsed_network_rawfile,sep = " ",header = F,as.is = T,col.names = c("v1","v2","weight"))
g <- graph_from_data_frame(g_data,directed = F)

# Check that the graph is weighted
# Should say TRUE
is_weighted(g)

# Check that the graph is not directed
# Should say FALSE
is.directed(g)

#Is the graph totally connected?
is.connected(g)

#Remove loops and multiple edges
g <-simplify(g,remove.multiple = T,remove.loops = T)

#Get number of nodes
length(V(g))

#Get number of edges
length(E(g))

#Edge Density
graph.density(g,loops = FALSE)

#Transitivity
cc <- transitivity(g,type="global")

#Diameter, using weights
#diam <- diameter(g,directed=FALSE)

#Diameter, not using weights
#diam <- diameter(g,directed=FALSE,weights=NA)

#assortativity
ass <- assortativity_degree(g, directed=F)
close <- closeness(g, mode="all", weights=NA)
eigen <- eigen_centrality(g, directed=FALSE, weights=NA)
bet <- betweenness(g, directed=FALSE, weights=NA)

#
# Examine and plot the degree distribution
#
deg.dist <- degree.distribution(g,cumulative = TRUE,mode="all")
plot(deg.dist, main = "Degree Distribution, Parsed Co-Occurence Network",
     col="darkblue",pch=10,cex=0.75,xlab="Degree", ylab="Cumulative Frequency",xlim=c(0,1000))
```

### 4.6 Maximal cliques in the parsed network with only edge weights >= 2000 (Table 4)
We also used the code below to identify maximal cliques in the parsed network (Table 4). You will find that there are actually 6 cliques reported, but 2 of these 6 contain a vertex that is not a food item ("or") so they were excluded in our manuscript report.


```python
cliq<- max_cliques(g)

# Examining the cliq variable allows us to see that the maximal clique size found is 16, 
# which is used below to investigate their contents
cliq2<-cliques(g,min=16,max=16)
length(cliq2)
cliq2[1]
cliq2[2]
cliq2[3]
cliq2[4]
cliq2[5]
cliq2[6]
```
