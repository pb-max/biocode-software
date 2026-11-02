#过滤指标1:最少表达基因数的细胞&最少表达细胞数的基因
selected_c <- WhichCells(sce.all, expression = nFeature_RNA > 300)
selected_f <- rownames(sce.all)[Matrix::rowSums(sce.all@assays$RNA@counts > 0 ) > 3]
sce.all.filt <- subset(sce.all, features = selected_f, cells = selected_c)
dim(sce.all)
#过滤前 25948  7827
dim(sce.all.filt) 
#过滤后 24653  7459
#可以看到，主要是过滤了基因，其次才是细胞


#过滤指标2:线粒体/核糖体基因比例(根据上面的violin图)
selected_mito <- WhichCells(sce.all.filt, expression = percent_mito < 15)
selected_ribo <- WhichCells(sce.all.filt, expression = percent_ribo > 3)
selected_hb <- WhichCells(sce.all.filt, expression = percent_hb < 0.1)
length(selected_hb)
length(selected_ribo)
length(selected_mito)
sce.all.filt <- subset(sce.all.filt, cells = selected_mito)
sce.all.filt <- subset(sce.all.filt, cells = selected_ribo)
#sce.all.filt <- subset(sce.all.filt, cells = selected_hb)
dim(sce.all.filt)
table(sce.all.filt$orig.ident) 

#可视化过滤后的情况
feats <- c("nFeature_RNA", "nCount_RNA")
p1_filtered=VlnPlot(sce.all.filt, group.by = "orig.ident", features = feats, pt.size = 0.1, ncol = 2) + 
  NoLegend()
ggsave(filename="Vlnplot1_filtered.pdf",plot=p1_filtered)
ggsave(filename="Vlnplot1_filtered.png",plot=p1_filtered)

feats <- c("percent_mito", "percent_ribo", "percent_hb")
p2_filtered=VlnPlot(sce.all.filt, group.by = "orig.ident", features = feats, pt.size = 0.1, ncol = 3) + 
  NoLegend()
ggsave(filename="Vlnplot2_filtered.pdf",plot=p2_filtered)
ggsave(filename="Vlnplot2_filtered.png",plot=p2_filtered)
dim(sce.all.filt)
### [1] 24653  7086


#过滤指标3:过滤特定基因
### Filter MALAT1 管家基因
sce.all.filt <- sce.all.filt[!grepl("MALAT1", rownames(sce.all.filt),ignore.case = T), ]
### Filter Mitocondrial 线粒体基因
sce.all.filt <- sce.all.filt[!grepl("^MT-", rownames(sce.all.filt),ignore.case = T), ]
### 当然，还可以过滤更多
dim(sce.all.filt)
### [1] 24639  7086

