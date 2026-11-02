##合并两个数据集
setwd('../')
dir.create("2-int")
getwd()
setwd("2-int/")
sce.all <- readRDS("../1-QC/sce.all_qc.rds")
sce.all <- sce.all.filt
sce.all

##拆分为2个seurat子对象（分开pca1和pca2)
table(sce.all@meta.data$orig.ident)
sce.all.list <- SplitObject(sce.all,split.by = "orig.ident")
sce.all.list

#对两个数据进行处理
#鉴定高变基因：用FindVariableFeatures函数来执行。默认情况下，每个dataset返回2000个基因，这些基因将用于下游分析，如PCA
for (i in 1:length(sce.all.list)){
  print(i)
     sce.all.list[[i]] <- NormalizeData(sce.all.list[[i]],verbose=FALSE)
     sce.all.list[[i]] <- FindVariableFeatures(sce.all.list[[i]],selection.method = "vst",
                                               nfeatures = 2000,verbose=FALSE)
}


#利用进行CCA对数据进行整合
library(Seurat)
alldata.anchors <- FindIntegrationAnchors(object.list = sce.all.list,dim=1:30,
                                          reduction = "cca")
sce.all.int <- IntegrateData(anchorset = alldata.anchors,dims = 1:30,new.assay.name = "CCA")
#运行IntegrateData之后，Seurat对象将包含一个具有整合（或“批次效应”）表达矩阵的新Assay
#原始值（未校正的值）仍存储在“RNA”分析的对象中，因此可以来回切换，然后使用这个新的整合矩阵进行下游分析和可视化
names(sce.all.int@assays)
sce.all.int@active.assay


# Run the standard workflow for visualization and clustering
sce.all.int <- ScaleData(sce.all.int, features = rownames(sce.all.int))
sce.all.int <- RunPCA(sce.all.int, npcs = 30, verbose = FALSE)
sce.all.int <- RunUMAP(sce.all.int, dims = 1:30)
sce.all.int <- RunTSNE(sce.all.int, dims = 1:30)
#CCA数据整合-可视化
p1.compare <- plot_grid(ncol=3,
                        DimPlot(sce.all,reduction = "pca",group.by = "orig.ident")+NoAxes()+ggtitle("PCA raw_data"),
                        DimPlot(sce.all,reduction = "tsne",group.by = "orig.ident")+NoAxes()+ggtitle("tSNE raw_data"),
                        DimPlot(sce.all,reduction = "umap",group.by = "orig.ident")+NoAxes()+ggtitle("UMAP raw_data"),
                        
                        DimPlot(sce.all.int,reduction = "pca",group.by = "orig.ident")+NoAxes()+ggtitle("PCA integrated"),
                        DimPlot(sce.all.int,reduction = "tsne",group.by = "orig.ident")+NoAxes()+ggtitle("tSNE integrated"),
                        DimPlot(sce.all.int,reduction = "umap",group.by = "orig.ident")+NoAxes()+ggtitle("UMAP integrated")
                        )
p1.compare
ggsave(plot = p1.compare,filename = "Before&After_int.pdf",width = 10,height = 7)
ggsave(plot = p1.compare,filename = "Before&After_int.png",width = 10,height = 7)
