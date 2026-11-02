#细胞周期评分
###标准化数据
sce.all.filt <- NormalizeData(sce.all.filt)
s.genes <- Seurat::cc.genes.updated.2019$s.genes
g2m.genes <- Seurat::cc.genes.updated.2019$g2m.genes
sce.all.filt <- CellCycleScoring(object = sce.all.filt,
                                 s.features = s.genes,
                                 g2m.features = g2m.genes,
                                 set.ident = TRUE)
p4 <- VlnPlot(sce.all.filt,features = c("S.Score","G2M.Score"),group.by = "orig.ident",
              ncol = 2,pt.size = 0.1)
ggsave(filename = "Vlnplot4_cycle.pdf",plot = p4)
ggsave(filename = "Vlnplot4_cycle.png",plot = p4)

#sce.all.filt@meta.data %>% ggplot(aes(S.Score,G2M.Score))+geom_point(aes(color=Phase)+theme_minimal())
sce.all.filt@meta.data  %>% ggplot(aes(S.Score,G2M.Score))+geom_point(aes(color=Phase))+
  theme_minimal()
ggsave(filename="cycle_details.pdf" )
ggsave(filename="cycle_details.png" )
#S.Score 较高的为S期，G2M.Score 较高的为G2M期，都比较低的是G1期

#查看细胞周期基因对细胞聚类的影响
sce.a <- RunPCA(sce.all.filt, features = c(s.genes, g2m.genes))
p1 <- DimPlot(sce.a, reduction = "pca", group.by = "Phase")
sce.b <- ScaleData(sce.a, vars.to.regress = c("S.Score", "G2M.Score"), features = rownames(sce.all.filt))
sce.c <- RunPCA(sce.b, features = c(s.genes, g2m.genes))
p2 <- DimPlot(sce.c, reduction = "pca", group.by = "Phase")
plotA <- CombinePlots(plots = list(p1, p2),legend="bottom")
ggplot2::ggsave(filename = 'cellcycle_pca.pdf',plot = plotA, width = 8, height = 5)

dim(scRNAb)

