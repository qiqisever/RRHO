# Suggest default step size
defaultftepSize <-function(list1, list2){
	n1<- length(list1)
	n2<- length(list2)
	result <- ceiling(min(sqrt(c(n1,n2))))	
	return(result)
}	



# Compute the overlaps between two *numeric* lists:
numericListOverlap<- function(sample1, sample2, stepsize){
  n<- length(sample1)
  overlap<- function(a,b) {
    f<- function(a,b) as.integer(sum(as.numeric(head(sample1,n=a) %in% head(sample2,n=b))))
    return( mapply(f, a, b) )
  }    
  result<- outer(seq(1,n,by=stepsize), seq(1,n,by=stepsize), overlap)  
  return(result)
  
}
## Testing:
n<- 100
sample1<- sample(n)
sample2<- sample(n)  
numericListOverlap(sample1, sample2, 10)








#Rank Rank Hypergeometric Overlap based on Plaisier et al., Nucleic Acids Research, 2010
RRHO <- function(list1, list2, stepsize=defaultftepSize(list1, list2), labels, plots=FALSE, outputdir=NULL, BY=FALSE) {
    ## list 1 is a data.frame from experiment 1 with two columns, column 1 is the Gene Identifier, column 2 is the signed ranking value (e.g. signed -log10(p-value) or fold change)
    ## list 2 is a data.frame from experiment 2 with two columns, column 1 is the Gene Identifier, column 2 is the signed ranking value (e.g. signed -log10(p-value) or fold change)
    ## stepsize indicates how many genes to increase by in each algorithm iteration

	if (length(list1[,1])!=length(unique(list1[,1])))
		stop('Non-unique gene identifier found in list1');
    if (length(list2[,1])!=length(unique(list2[,1])))
	    stop('Non-unique gene identifier found in list2');
    
    result <-list(hypermat=NA, hypermat.count=NA, n.items=nrow(list1), stepsize=stepsize, hypermat.by=NA) 

    # Order lists along list2
    list1 = list1[order(list1[,2],decreasing=TRUE),];
    list2 = list2[order(list2[,2],decreasing=TRUE),];
    nlist1 = length(list1[,1]);
    nlist2 = length(list2[,1]);
    
    ## Number of genes on the array
    N = max(nlist1,nlist2);
  
	hypermat.counts2 = numericListOverlap(list1[,2], list2[,2], stepsize)
    
    hypermat = matrix(data=NA,nrow=length(seq(1,nlist1,stepsize)),ncol=length(seq(1,nlist2,stepsize)));
    hypermat.counts = matrix(data=NA,nrow=length(seq(1,nlist1,stepsize)),ncol=length(seq(1,nlist2,stepsize)));
    countx = county = 0;
    ##Loop over the experiments
    for (i in seq(1,nlist1,stepsize)) {
        countx = countx + 1;
        for (j in seq(1,nlist2,stepsize)) {
            county = county + 1;
            ## Parameters for the hypergeometric test
            k = length(intersect(list1[1:i,1],list2[1:j,1]));
            s = length(list1[1:i,1]);
            M = length(list2[1:j,1]);
            ## Hypergeometric test
	    # note: phyper returns log in natural basis (not 10)
	    ## TODO: Jason (a) why k-1? (b) Note log is in exp base!
            hypermat[countx,county] = -phyper(k-1,M,N-M,s,lower.tail=FALSE,log.p=TRUE);
            hypermat.counts[countx,county] = k
            #print(hypermat[countx,county]);
        }
        county=0;
    }
    result$hypermat <- hypermat
    result$hypermat.counts <- hypermat.counts

  browser()
    ## Convert hypermat to a vector and Benjamini Yekutieli FDR correct
    if(BY){
	    hypermatvec = matrix(hypermat,nrow=nrow(hypermat)*ncol(hypermat),ncol=1);
	    hypermat.byvec = p.adjust(exp(-hypermatvec),method="BY");
	    hypermat.by = matrix(-log(hypermat.byvec),nrow=nrow(hypermat),ncol=ncol(hypermat));
	    result$hypermat.by <- hypermat.by
    }
    
    if (plots) {
	    require(VennDiagram);
	    require(grid)
	    if(missing(outputdir)) stop('When plots=TRUE, outputdir required.')
        ## Function to plot color bar
        ## Modified from http://www.colbyimaging.com/wiki/statistics/color-bars
        color.bar <- function(lut, min, max=-min, nticks=11, ticks=seq(min, max, len=nticks), title='') {
            scale = (length(lut)-1)/(max-min);
            plot(c(0,10), c(min,max), type='n', bty='n', xaxt='n', xlab='', yaxt='n', ylab='');
            mtext(title,2,2.3,cex=0.8);
            axis(2, round(ticks,0), las=1,cex.lab=0.8);
            for (i in 1:(length(lut)-1)) {
                y = (i-1)/scale + min;
                rect(0,y,10,y+1/scale, col=lut[i], border=NA);
            }
        }
        
	.filename <-paste("RRHOMap",labels[1],"_VS_",labels[2],".jpg",sep="") 
        jpeg(paste(outputdir,.filename,sep="/"),width=8,height=8,units="in",quality=100,res=150);

        jet.colors = colorRampPalette(c("#00007F", "blue", "#007FFF", "cyan", "#7FFF7F", "yellow", "#FF7F00", "red", "#7F0000"));
        layout(matrix(c(rep(1,5),2), 1, 6, byrow = TRUE));
        image(hypermat,xlab='',ylab='',col=jet.colors(100),axes=FALSE,main="Rank Rank Hypergeometric Overlap Map");
        mtext(labels[2],2,0.5);
        mtext(labels[1],1,0.5);
        ##mtext(paste("-log(BY P-value) =",max(hypermat.by)),3,0.5,cex=0.5);
        color.bar(jet.colors(100),min=min(hypermat,na.rm=TRUE),max=max(hypermat,na.rm=TRUE),nticks=6,title="-log(P-value)");
        dev.off();
        
        ## Make a rank scatter plot
        list2ind = match(list1[,1],list2[,1]);
        list1ind = 1:nlist1;
        corval = cor(list1ind,list2ind,method="spearman");
	.filename <-paste("RankScatter",labels[1],"_VS_",labels[2],".jpg",sep="") 
        jpeg(paste(outputdir,.filename,sep="/"),width=8,height=8,units="in",quality=100,res=150);
        plot(list1ind,list2ind,xlab=paste(labels[1],"(Rank)"),ylab=paste(labels[2],"(Rank)"),pch=20,main=paste("Rank-Rank Scatter (rho = ",signif(corval,digits=3),")",sep=""),cex=0.5);
	# TODO: Replace linear fit with LOESS
        model = lm(list2ind~list1ind);
        lines(predict(model),col="red",lwd=3);
        dev.off();
        
        ## Make a Venn Diagram for the most significantly associated points
        ## Upper Right Corner (Downregulated in both)
        maxind.ur = which(max(hypermat[ceiling(nrow(hypermat)/2):nrow(hypermat),ceiling(ncol(hypermat)/2):ncol(hypermat)],na.rm=TRUE)==hypermat,arr.ind=TRUE);
        indlist1.ur = seq(1,nlist1,stepsize)[maxind.ur[1]];
        indlist2.ur = seq(1,nlist2,stepsize)[maxind.ur[2]];
        genelist.ur = intersect(list1[indlist1.ur:nlist1,1],list2[indlist2.ur:nlist2,1]);
        ## Lower Right corner (Upregulated in both)
        maxind.lr = which(max(hypermat[1:(ceiling(nrow(hypermat)/2)-1),1:(ceiling(ncol(hypermat)/2)-1)],na.rm=TRUE)==hypermat,arr.ind=TRUE);
        indlist1.lr = seq(1,nlist1,stepsize)[maxind.lr[1]];
        indlist2.lr = seq(1,nlist2,stepsize)[maxind.lr[2]];
        genelist.lr = intersect(list1[1:indlist1.lr,1],list2[1:indlist2.lr,1]);
        
        ## Write out the gene lists of overlapping
	.filename <- paste(outputdir,"/RRHO_GO_MostDownregulated",labels[1],"_VS_",labels[2],".csv",sep="")
        write.table(genelist.ur,.filename,row.names=F,quote=F,col.names=F);
	.filename <- paste(outputdir,"/RRHO_GO_MostUpregulated",labels[1],"_VS_",labels[2],".csv",sep="")
        write.table(genelist.lr,.filename,row.names=F,quote=F,col.names=F);
        
	.filename <- paste(outputdir,"/RRHO_VennMost",labels[1],"__VS__",labels[2],".jpg",sep="")
	jpeg(.filename,width=8.5,height=5,units="in",quality=100,res=150);
        vp1 = viewport(x=0.25,y=0.5,width=0.5,height=0.9);
        vp2 = viewport(x=0.75,y=0.5,width=0.5,height=0.9);
        
        pushViewport(vp1);
        h1 = draw.pairwise.venn(length(indlist1.ur:nlist1),length(indlist2.ur:nlist2),length(genelist.ur),category=c(labels[1],labels[2]),scaled=TRUE,lwd=c(0,0),fill=c("cornflowerblue", "darkorchid1"),cex=1,cat.cex=1.2,cat.pos=c(0,0),ext.text=FALSE,ind=FALSE,cat.dist=0.01);
        grid.draw(h1);
        grid.text("Down Regulated",y=1);
        upViewport();
        pushViewport(vp2);
        h2 = draw.pairwise.venn(length(1:indlist1.lr),length(1:indlist2.lr),length(genelist.lr),category=c(labels[1],labels[2]),scaled=TRUE,lwd=c(0,0),fill=c("cornflowerblue", "darkorchid1"),cex=1,cat.cex=1.2,cat.pos=c(0,0),ext.text=FALSE,main="Negative",ind=FALSE,cat.dist=0.01);
        grid.draw(h2);
        grid.text("Up Regulated",y=1);
        dev.off();
    }
    return(result);
}
# Testing:
 list.length <- 100
 list.names <- paste('Gene',1:list.length, sep='')
 gene.list1<- data.frame(list.names, sample(100))
 gene.list2<- data.frame(list.names, sample(100))
 RRHO.example <-  RRHO(gene.list1, gene.list2)






# TODO: Function for FWER control using permutations
pvalRRHO <- function(RRHO.obj, replications, stepsize=RRHO.obj$stepsize, FUN= max){
  # RRHO.obj <- RRHO.example
  # FUN<- max
  # replications<- 100
  # stepsize <- RRHO.obj$stepsize
  # Note: min(pvals) maps to max(-log(pvals))
	n.items <- RRHO.obj$n.items
	result <- list(FUN=FUN, n.items=n.items, stepsize=stepsize )

	
	FUN.vals<- rep(NA, replications)
	for(i in 1:replications){
    # i<- 1
	  # Generate rankings and compute overlap
	  list.names <- paste('Gene',1:list.length, sep='')
	  sample1<- data.frame(list.names, sample(n.items))
	  sample2<- data.frame(list.names, sample(n.items))	  
	  .RRHO<- RRHO(sample1, sample2, stepsize=stepsize, plots=FALSE, BY=FALSE)
	  .clean.log.pvals<- na.omit(.RRHO$hypermat)
	  FUN.vals[i]<- FUN(.clean.log.pvals)
	}
		
	FUN.ecdf<- function(x)  min( ecdf(FUN.vals)(x) + 1/length(FUN.vals), 1)
	result$CDF.log.scale<- FUN.ecdf	  
  
  .clean.data<- na.omit(RRHO.obj$hypermat)
  FUN.observed<- FUN(.clean.data)
  
  result$pval<- 1-FUN.ecdf(FUN.observed)
	# Return pvale
	return(result)
}
## Testing:
pval.testing <- pvalRRHO(RRHO.example,100) 


