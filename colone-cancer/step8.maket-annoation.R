######## step5:细胞类型注释(根据marker gene)######
### setwd("/home/data/gma49/scRNA")
dir.create("../3-cell")
setwd("../3-cell") 

sce.all=readRDS( "E:/bioinformatics shixi/2-int/sce.all_int.rds")
table(sce.all@meta.data$seurat_clusters)
table(sce.all@meta.data$CCA_snn_res.0.8)

#展示按照不同标准进行分群的结果，并没有什么区别
p1=DimPlot(sce.all, reduction = "umap", group.by = "seurat_clusters",label = T) 
p2=DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.0.8",label = T) 
ggsave("umap_by_CCA_snn_res.0.8.pdf", plot = p1, width = 8, height = 7)
ggsave("umap_by_CCA_snn_res.0.8.png", plot = p1, width = 8, height = 7)
ggsave("umap_by_seurat_clusters.pdf", plot = p2, width = 8, height = 7)
ggsave("umap_by_seurat_clusters.png", plot = p2, width = 8, height = 7)
#各个细胞类型的marker。（这里就太考验生物学背景知识了
### T Cells (CD3D, CD3E, CD8A), 
### B cells (CD19, CD79A, MS4A1 [CD20]), 
### Plasma cells (IGHG1, MZB1, SDC1, CD79A), 
### Monocytes and macrophages (CD68, CD163, CD14),
### NK Cells (FGFBP2, FCG3RA, CX3CR1),  
### Photoreceptor cells (RCVRN), 
### Fibroblasts (FGF7, MME), 
### Endothelial cells (PECAM1, VWF). 
### epi or tumor (EPCAM, KRT19, PROM1, ALDH1A1, CD24).
### immune (CD45+,PTPRC), epithelial/cancer (EpCAM+,EPCAM), 
### stromal (CD10+,MME,fibo or CD31+,PECAM1,endo) 

library(ggplot2) 
#查看这些marker基因在各个cluster里的表达情况
genes_to_check = c('PTPRC', 'CD3D', 'CD3E', 'CD4','CD8A','CD19', 'CD79A', 'MS4A1' ,
                   'IGHG1', 'MZB1', 'SDC1',
                   'CD68', 'CD163', 'CD14', 
                   'TPSAB1' , 'TPSB2',  ### mast cells,
                   'RCVRN','FPR1' , 'ITGAM' ,
                   'FGF7','MME', 'ACTA2',
                   'PECAM1', 'VWF', 
                   'EPCAM' , 'KRT19', 'PROM1', 'ALDH1A1' )
library(stringr)  
#sce.all@assays$RNA
p_all_markers <- DotPlot(sce.all, features = genes_to_check,
                         assay='RNA'  )  + coord_flip()
p_all_markers
ggsave(plot=p_all_markers, filename="check_all_marker_by_seurat_cluster.pdf",width = 8, height = 6)
ggsave(plot=p_all_markers, filename="check_all_marker_by_seurat_cluster.png",width = 8, height= 6)
#初步定义后，心里大概有一个了解，再利用自己的相关知识开始细分

### 1、Tcells（T细胞）
genes_to_check = c('PTPRC', 'CD3D', 'CD3E', 'CD4','CD8A',
                   'CCR7', 'SELL' , 'TCF7','CXCR6' , 'ITGA1',
                   'FOXP3', 'IL2RA',  'CTLA4','GZMB', 'GZMK','CCL5',
                   'IFNG', 'CCL4', 'CCL3' ,
                   'PRF1' , 'NKG7') 
library(stringr)  
pT <- DotPlot(sce.all, features = genes_to_check,
              assay='RNA'  )  + coord_flip()+ggtitle("Tcells")
pT
ggsave(plot=pT, filename="check_Tcells_marker_by_seurat_cluster.pdf")

### mast cells, TPSAB1 and TPSB2 
### B cell,  CD79A  and MS4A1 (CD20) 
### naive B cells, such as MS4A1 (CD20), CD19, CD22, TCL1A, and CD83, 
### plasma B cells, such as CD38, TNFRSF17 (BCMA), and IGHG1/IGHG4

### 2、Bcells
genes_to_check = c('CD3D','MS4A1','CD79A',
                   'CD19', 'CD22', 'TCL1A',  'CD83', ###  naive B cells
                   'CD38','TNFRSF17','IGHG1','IGHG4', ### plasma B cells,
                   'TPSAB1' , 'TPSB2',  ### mast cells,
               
                   'PTPRC' ) 
pB <- DotPlot(sce.all, features = genes_to_check,
              assay='RNA'  )  + coord_flip()+ggtitle("Bcells")
pB
ggsave(plot=pB, filename="check_Bcells_marker_by_seurat_cluster.pdf")

### 3、Myeloid
genes_to_check = c('CD68', 'CD163', 'CD14',  'CD86', 'LAMP3', #### DC 
                   'CD68',  'CD163','MRC1','MSR1','ITGAE','ITGAM','ITGAX','SIGLEC7', 
                   'MAF','APOE','FOLR2','RELB','BST2','BATF3')
pMyeloi <- DotPlot(sce.all, features = unique(genes_to_check),
                   assay='RNA'  )  + coord_flip()+ggtitle("Myeloid")
pMyeloi
ggsave(plot=pMyeloi, filename="check_Myeloid_marker_by_seurat_cluster.pdf")


### epi or tumor (EPCAM, KRT19, PROM1, ALDH1A1, CD24).
### - alveolar type I cell (AT1; AGER+)
### - alveolar type II cell (AT2; SFTPA1)
### - secretory club cell (Club; SCGB1A1+)
### - basal airway epithelial cells (Basal; KRT17+)
### - ciliated airway epithelial cells (Ciliated; TPPP3+)

### 4、Epi
genes_to_check = c(  'EPCAM' , 'KRT19', 'PROM1','ALDH1A1' ,
                     'AGER','SFTPA1','SCGB1A1','KRT17','TPPP3',
                     'KRT4','KRT14','KRT8','KRT18',
                     'CD3D','PTPRC' ) 
pEpi <- DotPlot(sce.all, features = unique(genes_to_check),
                assay='RNA'  )  + coord_flip()+ggtitle("Epi")
pEpi
ggsave(plot=pEpi, filename="check_epi_marker_by_seurat_cluster.pdf")

### 5、stromal
genes_to_check = c('TEK',"PTPRC","EPCAM","PDPN","PECAM1",'PDGFRB',
                   'CSPG4','GJB2', 'RGS5','ITGA7',
                   'ACTA2','RBP1','CD36', 'ADGRE5','COL11A1','FGF7', 'MME')
pStromal <- DotPlot(sce.all, features = unique(genes_to_check),
                    assay='RNA'  )  + coord_flip()+ggtitle("stromal")

pStromal
ggsave(plot=pStromal, filename="check_stromal_marker_by_seurat_cluster.pdf")


p5=pT+pB+pMyeloi+pEpi+pStromal
ggsave(plot=p5, filename="pT+pB+pMyeloi+pEpi+pStromal.png",width=16 ,height=8)
ggsave(plot=p5, filename="pT+pB+pMyeloi+pEpi+pStromal.pdf",width=16 ,height=8)
### 需要自行看图，定细胞亚群：  
celltype=data.frame(ClusterID=0:15,
                    celltype='unkown')
celltype[celltype$ClusterID %in% c(0,3,7),2]='Tcells' 
celltype[celltype$ClusterID %in% c(15),2]='NK'  
celltype[celltype$ClusterID %in% c(13),2]='Bcells'  
celltype[celltype$ClusterID %in% c(11),2]='myeloid'
celltype[celltype$ClusterID %in% c(2,5,6,14),2]='epithelial'
celltype[celltype$ClusterID %in% c( 1,8),2]='endo' 
celltype[celltype$ClusterID %in% c(4,9),2]='SMC'  
celltype[celltype$ClusterID %in% c(12),2]='fibo'  
celltype[celltype$ClusterID %in% c(10),2]='mast'  

head(celltype)
celltype 
table(celltype$celltype)#9种细胞类型，基本和文章中一致

sce.all@meta.data$celltype = "NA"
for(i in 1:nrow(celltype)){
  sce.all@meta.data[which(sce.all@meta.data$CCA_snn_res.0.8 == celltype$ClusterID[i]),'celltype'] <- celltype$celltype[i]}
table(sce.all@meta.data$celltype)

genes_to_check = c('PTPRC', 'CD3D', 'CD3E', 'CD4','CD8A','NKG7',
                   'CD19', 'CD79A', 'MS4A1' ,
                   'IGHG1', 'MZB1', 'SDC1',
                   'CD68', 'CD163', 'CD14', 
                   'TPSAB1' , 'TPSB2',  ### mast cells,
                   'RCVRN','FPR1' , 'ITGAM' ,
                   'FGF7','MME', 'ACTA2',
                   'PECAM1', 'VWF', 
                   'EPCAM' , 'KRT19', 'PROM1', 'ALDH1A1' )
p <- DotPlot(sce.all, features = genes_to_check,
             assay='RNA' ,group.by = 'celltype' )  + coord_flip()

p
ggsave(plot=p, filename="check_marker_by_celltype.pdf",width = 8, height = 5)
ggsave(plot=p, filename="check_marker_by_celltype.png",width = 8, height = 5)
#根据确定的细胞类型，给细胞加上注释，并对每个cluster进行注释
table(sce.all@meta.data$celltype,sce.all@meta.data$CCA_snn_res.0.8)

DimPlot(sce.all, reduction = "umap", group.by = "celltype",label = T)  
ggsave('umap_by_celltype.pdf')
ggsave('umap_by_celltype.png')
saveRDS(sce.all, "sce.all_cell.rds")
