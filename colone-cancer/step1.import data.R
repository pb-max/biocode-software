rm(list = ls())#魔幻操作，一键清空~
options(stringsAsFactors = F)
library(data.table)
library(R.utils)
pca1 <- fread("./GSM4773521_PCa1_gene_counts_matrix.txt.gz",data.table = F)
#这里的warning message 不要怕，是因为读取的时候把行名当做了一列，所以多出来一列‘V1’，后面会删掉这里一列再重新添加行名
pca1[1:4,1:4]
pca2 <- fread('./GSM4773522_PCa2_gene_counts_matrix.txt.gz',data.table = F)
pca2[1:4,1:4]
d1 <- pca1[ ,-1]
rownames(d1) <- pca1[ ,1]

#创建SeuratObject
#分别创建SeuratObject
scRNA1 <- CreateSeuratObject(counts = d1,#和文章一样，初步质控
                             min.cells = 3,#在不少于三个细胞中表达
                             min.features = 200,#基因数不少于200
                             project = "pca1")
#24576 features & 2896 samples

d2 = pca2[ ,-1]
rownames(d2) <- pca2