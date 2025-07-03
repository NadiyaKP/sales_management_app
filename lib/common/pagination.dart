import 'package:flutter/material.dart';

class SlidingPaginationControls extends StatefulWidget {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;
  final int maxVisiblePages;
  final Function(int) onPageChanged;
  final bool isLoading;

  const SlidingPaginationControls({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.itemsPerPage = 100,
    this.maxVisiblePages = 3,
    required this.onPageChanged,
    this.isLoading = false,
  });

  @override
  State<SlidingPaginationControls> createState() => _SlidingPaginationControlsState();
}

class _SlidingPaginationControlsState extends State<SlidingPaginationControls> {
  bool _isExpanded = false;

  // Calculate total pages based on server data
  int get totalPages {
    if (widget.totalItems <= 0) return 1;
    return (widget.totalItems / widget.itemsPerPage).ceil();
  }

  // Check if a specific page has items
  bool _hasItemsOnPage(int pageNumber) {
    if (pageNumber <= 0) return false;
    int startItem = (pageNumber - 1) * widget.itemsPerPage + 1;
    return startItem <= widget.totalItems;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            height: 15,
            width: double.infinity,
            color: Colors.blue.shade100,
            child: Center(
              child: Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isExpanded ? 60 : 0,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          color: Colors.blueGrey.shade100,
          child: _isExpanded ? _buildPaginationContent() : null,
        ),
      ],
    );
  }

  Widget _buildPaginationContent() {
    return Column(
      children: [
        // Page info row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Page ${widget.currentPage} of $totalPages',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Pagination controls row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildPaginationButtons(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPaginationButtons() {
    final List<Widget> pageButtons = [];

    // Calculate visible page range
    int startPage = 1;
    int endPage = totalPages;

    if (totalPages > widget.maxVisiblePages) {
      int halfVisible = widget.maxVisiblePages ~/ 2;
      startPage = (widget.currentPage - halfVisible).clamp(1, totalPages - widget.maxVisiblePages + 1);
      endPage = (startPage + widget.maxVisiblePages - 1).clamp(widget.maxVisiblePages, totalPages);
      
      // Adjust start page if end page is at maximum
      if (endPage == totalPages) {
        startPage = (totalPages - widget.maxVisiblePages + 1).clamp(1, totalPages);
      }
    }

    // First page button
    pageButtons.add(_paginationIcon(Icons.first_page,
        enabled: widget.currentPage > 1 && _hasItemsOnPage(1) && !widget.isLoading,
        onTap: () {
          if (_hasItemsOnPage(1) && !widget.isLoading) {
            widget.onPageChanged(1);
          }
        }));

    // Previous page button
    pageButtons.add(_paginationIcon(Icons.chevron_left,
        enabled: widget.currentPage > 1 && _hasItemsOnPage(widget.currentPage - 1) && !widget.isLoading,
        onTap: () {
          int prevPage = widget.currentPage - 1;
          if (_hasItemsOnPage(prevPage) && !widget.isLoading) {
            widget.onPageChanged(prevPage);
          }
        }));

    // First page number if not in visible range
    if (startPage > 1) {
      if (_hasItemsOnPage(1)) {
        pageButtons.add(_buildPageButton(1));
      }
      if (startPage > 2) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 10,
          )),
        ));
      }
    }

    // Visible page numbers
    for (int i = startPage; i <= endPage; i++) {
      if (_hasItemsOnPage(i)) {
        pageButtons.add(_buildPageButton(i));
      }
    }

    // Last page number if not in visible range
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 10,
          )),
        ));
      }
      if (_hasItemsOnPage(totalPages)) {
        pageButtons.add(_buildPageButton(totalPages));
      }
    }

    // Next page button
    pageButtons.add(_paginationIcon(Icons.chevron_right,
        enabled: widget.currentPage < totalPages && _hasItemsOnPage(widget.currentPage + 1) && !widget.isLoading,
        onTap: () {
          int nextPage = widget.currentPage + 1;
          if (_hasItemsOnPage(nextPage) && !widget.isLoading) {
            widget.onPageChanged(nextPage);
          }
        }));

    // Last page button
    pageButtons.add(_paginationIcon(Icons.last_page,
        enabled: widget.currentPage < totalPages && _hasItemsOnPage(totalPages) && !widget.isLoading,
        onTap: () {
          if (_hasItemsOnPage(totalPages) && !widget.isLoading) {
            widget.onPageChanged(totalPages);
          }
        }));

    return pageButtons;
  }

  Widget _buildPageButton(int pageNumber) {
    bool hasItems = _hasItemsOnPage(pageNumber);
    
    return GestureDetector(
      onTap: () {
        if (pageNumber != widget.currentPage && hasItems && !widget.isLoading) {
          widget.onPageChanged(pageNumber);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.currentPage == pageNumber
              ? Colors.blue.shade600
              : (hasItems ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.currentPage == pageNumber
                ? Colors.blue.shade600
                : (hasItems ? Colors.white.withOpacity(0.3) : Colors.grey.shade400),
          ),
        ),
        child: widget.isLoading && widget.currentPage == pageNumber
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.currentPage == pageNumber ? Colors.white : Colors.blue.shade600,
                  ),
                ),
              )
            : Text(
                '$pageNumber',
                style: TextStyle(
                  color: widget.currentPage == pageNumber 
                      ? Colors.white 
                      : (hasItems ? Colors.white : Colors.grey.shade600),
                  fontWeight: widget.currentPage == pageNumber
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 10,
                ),
              ),
      ),
    );
  }

  Widget _paginationIcon(IconData icon,
      {required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.2) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }
}