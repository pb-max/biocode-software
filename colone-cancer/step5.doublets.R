#过滤doublets
########检测doublets
#Doublets 被定义为在相同细胞barcode下测序的两个细胞（例如被捕获在同一液滴中）
sce.all.filt <- FindVariableFeatures(sce.all.filt)
sce.all.filt <- ScaleData(sce.all.filt,vars.to.regress = c("nFeature_RNA","percent_mito"))
sce.all.filt <- RunPCA(sce.all.filt,npcs = 20)
sce.all.filt <- RunTSNE(sce.all.filt,npcs = 20)
sce.all.filt <- RunUMAP(sce.all.filt,dims = 1:10)
### define the expected number of doublet cells
nExp <- round(ncol(sce.all.filt)*0.04)###expect 4% doublets
library(DoubletFinder)
#这个DoubletFinder 包的输入是经过预处理（包括归一化，降维，但不一定聚类）的Seurat 对象
sce.all.filt <- doubletFinder_v3(sce.all.filt,pN=0.25,pK = 0.09,nExp = nExp,PCs = 1:10)

###### 找Doublets

####DF 的名字不是固定的，因此从sce.all.filt@meta.data列名中提取比较保险
DF.name <- colnames(sce.all.filt@meta.data)[grep("DF.classification",colnames(sce.all.filt@meta.data))]
p5.vlnplot <- cowplot::plot_grid(ncol = 2,DimPlot(sce.all.filt,group.by = "orig.ident")+NoAxes(),
                                 DimPlot(sce.all.filt,group.by = DF.name)+NoAxes())
ggsave(filename = "doublet_vlnplot.pdf",plot = p5.vlnplot)
ggsave(filename = "doublet_vlngplot.png",plot = p5.vlnplot)

####过滤doublet
sce.all.filt <- sce.all.filt[ ,sce.all.filt@meta.data[ ,DF.name]== "Singlet"]
##过滤到此结束
##最后过滤结果
dim(sce.all.filt)
#[1]24639 6803
dim(sce.all)
#[1]25948 7827
saveRDS(sce.all.filt,"sce.all_qc.rds")
###rm(list=ls())
#dev.off()
#上面我们用merge 函数合并两个数据集团，批次效应不明显可以使用，但如果样本量比较大，并且有批次效应，或者跨测序
#平台的情况，可以使用CCA进行整合
